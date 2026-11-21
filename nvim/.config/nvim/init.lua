-- Neovim 0.12+ IDE: vim.pack + mini.nvim + treesitter + LSP. Press <Space> for mappings.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

for _, module in ipairs({
  'plugins', 'options', 'ui', 'editing', 'navigation', 'git', 'terminal', 'treesitter', 'lsp',
}) do
  require('config.' .. module)
end
