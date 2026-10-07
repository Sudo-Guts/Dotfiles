return {
  cmd = { "ruff", "server" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
  on_attach = function(client)
    -- Pyright proporciona documentación y navegación de símbolos.
    client.server_capabilities.hoverProvider = false
  end,
}
