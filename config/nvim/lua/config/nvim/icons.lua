local M = {}

-- Seleccionar antes de abrir Neovim: DOTFILES_ICON_STYLE=nerd|unicode|plain.
local symbols = {
  save = { "󰆓", "◇" },
  close = { "", "×" },
  search = { "", "⌕" },
  select_all = { "󰒅", "▣" },
  undo = { "", "↶" },
  redo = { "", "↷" },
  copy = { "", "▤" },
  cut = { "", "✂" },
  left = { "", "←" },
  right = { "", "→" },
  file = { "", "□" },
  terminal = { "", ">_" },
  definition = { "", "↗" },
  diagnostics = { "", "!" },
  project = { "󰳐", "◇" },
  index = { "", "≡" },
  compile = { "", "⚒" },
  log = { "", "▤" },
  stop = { "", "■" },
  make = { "󰙨", "⚒" },
  target = { "", "◎" },
  run = { "", "▶" },
  simulate = { "󰙨", "▷" },
  waves = { "󰘇", "∿" },
  settings = { "", "⚙" },
  references = { "", "↔" },
  implementation = { "", "↳" },
  documentation = { "", "▥" },
  edit = { "", "✎" },
  action = { "", "◇" },
  signature = { "󰘧", "ƒ" },
  format = { "󰉣", "≡" },
  replace = { "󰛔", "⇄" },
  symbols = { "󰘦", "ƒ" },
  folder = { "", "▱" },
  position = { "", "•" },
  jump = { "", "↗" },
  tree = { "", "⋮" },
  debug = { "", "◇" },
  breakpoint = { "", "●" },
  step_over = { "󰆷", "↷" },
  step_into = { "󰆹", "↳" },
  step_out = { "󰆸", "↰" },
  window = { "", "▣" },
  git = { "", "⑂" },
  code = { "", "<>" },
  buffers = { "", "▢" },
}

function M.label(name, text)
  local style = vim.g.dotfiles_icon_style or vim.env.DOTFILES_ICON_STYLE or "nerd"
  if style == "plain" then
    return text
  end
  local icon = assert(symbols[name], "Icono desconocido: " .. name)[style == "unicode" and 2 or 1]
  return icon .. " " .. text
end

return M
