local M = {}
local records, listeners = {}, {}

function M.log_path(root)
  return vim.fn.stdpath("state") .. "/projects/" .. vim.fn.sha256(vim.fs.normalize(root)) .. "/latest.log"
end

function M.subscribe(root, callback)
  root = vim.fs.normalize(root)
  listeners[root] = listeners[root] or {}
  listeners[root][callback] = true
  return function()
    if listeners[root] then
      listeners[root][callback] = nil
    end
  end
end

local function notify(root)
  for callback in pairs(listeners[root] or {}) do
    local ok, err = pcall(callback)
    if not ok then
      vim.notify(tostring(err), vim.log.levels.ERROR)
    end
  end
end

function M.status(root)
  local record = records[vim.fs.normalize(root)]
  if not record then
    return { "Proceso: sin ejecutar en esta sesión" }
  end
  local states = {
    running = "en curso",
    stopping = "deteniendo",
    success = "terminado",
    failed = "falló",
    cancelled = "cancelado",
    timeout = "tiempo agotado",
  }
  return {
    "Proceso: " .. states[record.state] .. (record.code and " · código " .. record.code or ""),
    "Etapa: " .. record.stage,
    "Comando: " .. record.title,
  }
end

function M.language(root)
  local record = records[vim.fs.normalize(root)]
  return record and record.language
end

-- Actualizar solamente la parte modificada del archivo y del buffer visible.
function M.flush(record)
  local dirty = record.dirty
  if dirty then
    local tail = {}
    for index = dirty, #record.lines do
      tail[#tail + 1] = record.lines[index]
    end
    local text = table.concat(tail, "\n") .. "\n"
    local offset = record.offsets[dirty] or 0
    local fd = assert(vim.uv.fs_open(record.path, "r+", 420))
    local written = 0
    while written < #text do
      local count, err = vim.uv.fs_write(fd, text:sub(written + 1), offset + written)
      if not count or count == 0 then
        vim.uv.fs_close(fd)
        error(err or "No se pudo escribir el registro")
      end
      written = written + count
    end
    assert(vim.uv.fs_ftruncate(fd, offset + #text))
    assert(vim.uv.fs_close(fd))
    local position = offset
    for index = dirty, #record.lines do
      record.offsets[index] = position
      position = position + #record.lines[index] + 1
      record.offsets[index + 1] = position
    end
    local buf = vim.fn.bufnr(record.path)
    if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
      local previous = vim.api.nvim_buf_line_count(buf)
      local follow, views = {}, {}
      for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        if vim.api.nvim_win_get_cursor(win)[1] >= previous then
          follow[#follow + 1] = win
        else
          views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
        end
      end
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, math.min(dirty - 1, previous), -1, false, tail)
      vim.bo[buf].modified, vim.bo[buf].modifiable = false, false
      for _, win in ipairs(follow) do
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_set_cursor(win, { #record.lines, 0 })
        end
      end
      for win, view in pairs(views) do
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_call(win, function()
            vim.fn.winrestview(view)
          end)
        end
      end
    end
    record.dirty = nil
  end
  notify(record.root)
end

local function dirty(record, index)
  record.dirty = math.min(record.dirty or index, index)
end

-- Conservar las secuencias ANSI incompletas entre fragmentos de salida.
local function clean(stream, data)
  local result = {}
  for index = 1, #data do
    local ch = data:sub(index, index)
    if stream.escape == "csi" then
      if ch:match("[@-~]") then
        stream.escape = nil
      end
    elseif stream.escape == "osc" then
      if ch == "\7" then
        stream.escape = nil
      elseif ch == "\27" then
        stream.escape = "osc_end"
      end
    elseif stream.escape == "osc_end" then
      if ch == "\\" then
        stream.escape = nil
      else
        stream.escape = "osc"
      end
    elseif stream.escape == "start" then
      stream.escape = ch == "[" and "csi" or ch == "]" and "osc" or nil
    elseif ch == "\27" then
      stream.escape = "start"
    elseif ch ~= "\0" then
      result[#result + 1] = ch
    end
  end
  return table.concat(result)
end

function M.clean(text)
  return clean({}, text)
end

local function line(record, stream, text)
  if not stream.index then
    record.lines[#record.lines + 1] = ""
    stream.index = #record.lines
  end
  local index = stream.index
  if stream.carriage then
    record.lines[index] = ""
    stream.carriage = false
  end
  record.lines[index] = record.lines[index] .. text
  dirty(record, index)
end

function M.feed(record, channel, data)
  if record.closed or not data or data == "" then
    return
  end
  local stream = record.streams[channel]
  stream.raw[#stream.raw + 1] = data
  data = clean(stream, data)
  local position = 1
  while position <= #data do
    local boundary = data:find("[\r\n]", position)
    local text = data:sub(position, boundary and boundary - 1 or #data)
    if text ~= "" then
      line(record, stream, text)
    end
    if not boundary then
      break
    end
    if data:sub(boundary, boundary) == "\r" then
      stream.carriage = true
    else
      if not stream.index then
        line(record, stream, "")
      end
      stream.index, stream.carriage = nil, false
    end
    position = boundary + 1
  end
  if not record.timer then
    record.timer = vim.defer_fn(function()
      record.timer = nil
      if not record.closed then
        M.flush(record)
      end
    end, 40)
  end
end

function M.start(root, command, cwd, opts)
  opts = opts or {}
  root = vim.fs.normalize(root)
  local path = M.log_path(root)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local lines = opts.append and vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
  local title = table.concat(vim.tbl_map(vim.fn.shellescape, command), " ")
  local record = {
    root = root,
    path = path,
    title = title,
    stage = opts.stage or vim.fn.fnamemodify(command[1], ":t"),
    state = "running",
    lines = lines,
    offsets = {},
    dirty = 1,
    started = vim.uv.hrtime(),
    timeout_ms = opts.timeout_ms,
    language = opts.language or M.language(root),
    streams = { stdout = { raw = {} }, stderr = { raw = {} } },
  }
  vim.list_extend(lines, { "Etapa: " .. record.stage, "Directorio: " .. cwd, "$ " .. title })
  records[root] = record
  -- Crear el archivo antes del primer volcado incremental.
  local fd = assert(vim.uv.fs_open(path, "w", 420))
  assert(vim.uv.fs_close(fd))
  M.flush(record)
  return record
end

function M.stopping(record)
  record.cancelled, record.state = true, "stopping"
  notify(record.root)
end

function M.finish(record, result)
  record.closed = true
  if record.timer then
    if not record.timer:is_closing() then
      record.timer:stop()
      record.timer:close()
    end
    record.timer = nil
  end
  result.stdout = result.stdout or table.concat(record.streams.stdout.raw)
  result.stderr = result.stderr or table.concat(record.streams.stderr.raw)
  record.code = result.code
  local elapsed = (vim.uv.hrtime() - record.started) / 1e6
  record.state = record.cancelled and "cancelled"
    or (record.timeout_ms and result.code == 124 and elapsed >= record.timeout_ms and "timeout")
    or (result.code == 0 and "success" or "failed")
  local notes = { cancelled = " (detenido por el usuario)", timeout = " (tiempo agotado)" }
  vim.list_extend(record.lines, {
    "Salida: " .. result.code .. "; señal: " .. (result.signal or 0) .. (notes[record.state] or ""),
    "",
  })
  dirty(record, #record.lines - 1)
  M.flush(record)
  return result
end

return M
