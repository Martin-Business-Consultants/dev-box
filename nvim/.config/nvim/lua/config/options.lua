require('mini.basics').setup({
  options = { extra_ui = true },
  mappings = { windows = true },
  autocommands = { relnum_in_visual_mode = true },
})

for name, value in pairs({
  relativenumber = true,
  scrolloff = 8,
  sidescrolloff = 8,
  tabstop = 2,
  shiftwidth = 2,
  expandtab = true,
  updatetime = 250,
  confirm = true,
  winborder = 'rounded',
  clipboard = 'unnamedplus',
}) do
  vim.o[name] = value
end

-- Over SSH, yank to the local clipboard via OSC 52 and paste from nvim's own register.
if vim.env.SSH_TTY then
  local osc52 = require('vim.ui.clipboard.osc52')
  local paste = function() return { vim.fn.split(vim.fn.getreg(''), '\n'), vim.fn.getregtype('') } end
  vim.g.clipboard = {
    name = 'OSC 52',
    copy = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
    paste = { ['+'] = paste, ['*'] = paste },
  }
end

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = { spacing = 2, source = 'if_many' },
  float = { source = 'if_many' },
  signs = true,
  underline = true,
})
