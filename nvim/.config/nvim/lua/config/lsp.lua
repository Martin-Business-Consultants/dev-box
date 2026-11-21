local util = require('config.util')

-- Servers are installed by mise (~/.config/mise/config.toml).
vim.lsp.config('*', { capabilities = MiniCompletion.get_lsp_capabilities() })
vim.lsp.config('lua_ls', {
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
    },
  },
})
vim.lsp.enable({ 'lua_ls', 'ts_ls', 'ruby_lsp', 'bashls', 'jsonls', 'cssls', 'html' })

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local buf = { buffer = ev.buf }
    local visual = { buffer = ev.buf, mode = { 'n', 'x' } }
    local map = function(lhs, rhs, desc, opts) util.map(lhs, rhs, desc, opts or buf) end

    map('gd', vim.lsp.buf.definition, 'Definition')
    map('gD', vim.lsp.buf.declaration, 'Declaration')
    map('<Leader>la', vim.lsp.buf.code_action, 'Code action', visual)
    map('<Leader>lf', function() vim.lsp.buf.format({ async = true }) end, 'Format', visual)
    map('<Leader>lr', vim.lsp.buf.rename, 'Rename')
    map('<Leader>lR', util.pick('lsp scope="references"'), 'References')
    map('<Leader>ld', vim.diagnostic.open_float, 'Line diagnostics')
    map('<Leader>li', function()
      local filter = { bufnr = ev.buf }
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
    end, 'Toggle inlay hints')
  end,
})
