-- Neovim 0.12+ IDE: vim.pack + mini.nvim + treesitter + LSP
-- Update plugins: :lua vim.pack.update()    Update parsers: :TSUpdate
-- Press <Space> and wait to see all leader mappings (mini.clue).

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Rebuild treesitter parsers whenever nvim-treesitter itself updates
vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    if ev.data.spec.name == 'nvim-treesitter' and ev.data.kind == 'update' then
      if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
      vim.cmd('TSUpdate')
    end
  end,
})

vim.pack.add({
  'https://github.com/nvim-mini/mini.nvim',
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main' },
  'https://github.com/neovim/nvim-lspconfig',
  'https://github.com/rafamadriz/friendly-snippets',
}, { confirm = false })

local map = function(lhs, rhs, desc, mode)
  vim.keymap.set(mode or 'n', lhs, rhs, { desc = desc })
end

-- ============================ Options ============================
require('mini.basics').setup({
  options = { extra_ui = true },
  mappings = { windows = true },
  autocommands = { relnum_in_visual_mode = true },
})
local o = vim.o
o.relativenumber = true
o.scrolloff = 8
o.sidescrolloff = 8
o.tabstop = 2
o.shiftwidth = 2
o.expandtab = true
o.updatetime = 250
o.confirm = true
o.winborder = 'rounded'
o.clipboard = 'unnamedplus'

-- Over SSH: yank to your local clipboard via OSC 52; paste from nvim's register
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

-- ============================ UI ============================
require('mini.icons').setup()
MiniIcons.mock_nvim_web_devicons()
if not pcall(vim.cmd.colorscheme, 'miniwinter') then vim.cmd.colorscheme('default') end

require('mini.notify').setup()
vim.notify = MiniNotify.make_notify()
require('mini.statusline').setup()
require('mini.tabline').setup()
require('mini.sessions').setup({ autowrite = true })
require('mini.starter').setup()
require('mini.cursorword').setup()
require('mini.trailspace').setup()
require('mini.indentscope').setup({
  draw = { animation = require('mini.indentscope').gen_animation.none() },
})

local hipatterns = require('mini.hipatterns')
hipatterns.setup({
  highlighters = {
    fixme = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' },
    hack  = { pattern = '%f[%w]()HACK()%f[%W]',  group = 'MiniHipatternsHack' },
    todo  = { pattern = '%f[%w]()TODO()%f[%W]',  group = 'MiniHipatternsTodo' },
    note  = { pattern = '%f[%w]()NOTE()%f[%W]',  group = 'MiniHipatternsNote' },
    hex_color = hipatterns.gen_highlighter.hex_color(),
  },
})

local miniclue = require('mini.clue')
miniclue.setup({
  triggers = {
    { mode = 'n', keys = '<Leader>' }, { mode = 'x', keys = '<Leader>' },
    { mode = 'n', keys = 'g' },        { mode = 'x', keys = 'g' },
    { mode = 'n', keys = "'" },        { mode = 'n', keys = '`' },
    { mode = 'x', keys = "'" },        { mode = 'x', keys = '`' },
    { mode = 'n', keys = '"' },        { mode = 'x', keys = '"' },
    { mode = 'i', keys = '<C-r>' },    { mode = 'c', keys = '<C-r>' },
    { mode = 'i', keys = '<C-x>' },
    { mode = 'n', keys = '<C-w>' },
    { mode = 'n', keys = 'z' },        { mode = 'x', keys = 'z' },
    { mode = 'n', keys = '[' },        { mode = 'n', keys = ']' },
  },
  clues = {
    { mode = 'n', keys = '<Leader>a', desc = '+AI' },
    { mode = 'n', keys = '<Leader>b', desc = '+Buffer' },
    { mode = 'n', keys = '<Leader>f', desc = '+Find' },
    { mode = 'n', keys = '<Leader>g', desc = '+Git' },
    { mode = 'n', keys = '<Leader>l', desc = '+LSP' },
    { mode = 'n', keys = '<Leader>t', desc = '+Terminal' },
    miniclue.gen_clues.builtin_completion(),
    miniclue.gen_clues.g(),
    miniclue.gen_clues.marks(),
    miniclue.gen_clues.registers(),
    miniclue.gen_clues.windows(),
    miniclue.gen_clues.z(),
  },
  window = { delay = 300 },
})

-- ============================ Editing ============================
require('mini.ai').setup()
require('mini.align').setup()
require('mini.bracketed').setup()
require('mini.bufremove').setup()
require('mini.jump').setup()
require('mini.move').setup()       -- Alt-h/j/k/l moves lines/selections
require('mini.pairs').setup()
require('mini.splitjoin').setup()  -- gS
require('mini.surround').setup()   -- sa / sd / sr
require('mini.misc').setup()
MiniMisc.setup_restore_cursor()
MiniMisc.setup_auto_root()

local snippets = require('mini.snippets')
snippets.setup({ snippets = { snippets.gen_loader.from_lang() } })  -- expand: <C-j>

require('mini.completion').setup()
vim.keymap.set('i', '<Tab>',   [[pumvisible() ? "\<C-n>" : "\<Tab>"]],   { expr = true })
vim.keymap.set('i', '<S-Tab>', [[pumvisible() ? "\<C-p>" : "\<S-Tab>"]], { expr = true })
_G.cr_action = function()
  if vim.fn.complete_info()['selected'] ~= -1 then return '\25' end -- <C-y>
  return MiniPairs.cr()
end
vim.keymap.set('i', '<CR>', 'v:lua.cr_action()', { expr = true })

-- ============================ Navigation ============================
require('mini.files').setup({ windows = { preview = true, width_preview = 60 } })
require('mini.pick').setup()
require('mini.extra').setup()
require('mini.visits').setup()
vim.ui.select = MiniPick.ui_select

map('<Leader>e', function() MiniFiles.open(vim.api.nvim_buf_get_name(0)) end, 'Explorer (file)')
map('<Leader>E', function() MiniFiles.open() end, 'Explorer (cwd)')
map('<Leader><Space>', '<Cmd>Pick files<CR>', 'Find files')
map('<Leader>/', '<Cmd>Pick grep_live<CR>', 'Grep')
map('<Leader>ff', '<Cmd>Pick files<CR>', 'Files')
map('<Leader>fg', '<Cmd>Pick grep_live<CR>', 'Grep live')
map('<Leader>fw', '<Cmd>Pick grep pattern="<cword>"<CR>', 'Grep word')
map('<Leader>fb', '<Cmd>Pick buffers<CR>', 'Buffers')
map('<Leader>fh', '<Cmd>Pick help<CR>', 'Help')
map('<Leader>fr', '<Cmd>Pick resume<CR>', 'Resume')
map('<Leader>fo', '<Cmd>Pick oldfiles<CR>', 'Recent files')
map('<Leader>fv', '<Cmd>Pick visit_paths<CR>', 'Visited paths')
map('<Leader>fd', '<Cmd>Pick diagnostic<CR>', 'Diagnostics')
map('<Leader>fk', '<Cmd>Pick keymaps<CR>', 'Keymaps')
map('<Leader>fc', '<Cmd>Pick commands<CR>', 'Commands')
map('<Leader>fs', '<Cmd>Pick lsp scope="document_symbol"<CR>', 'Symbols (buffer)')
map('<Leader>fS', '<Cmd>Pick lsp scope="workspace_symbol"<CR>', 'Symbols (workspace)')

map('<Leader>bd', function() MiniBufremove.delete() end, 'Delete buffer')
map('<Leader>bo', '<Cmd>%bd|e#|bd#<CR>', 'Delete other buffers')
map('<Leader>w', '<Cmd>write<CR>', 'Write')
map('<Leader>q', '<Cmd>quit<CR>', 'Quit')
map('<Esc>', '<Cmd>nohlsearch<CR>', 'Clear search')

-- ============================ Git ============================
require('mini.git').setup()
require('mini.diff').setup({ view = { style = 'sign' } })
map('<Leader>gs', function() MiniGit.show_at_cursor() end, 'Show at cursor')
map('<Leader>gd', function() MiniDiff.toggle_overlay() end, 'Diff overlay')
map('<Leader>gb', '<Cmd>vertical Git blame -- %<CR>', 'Blame')
map('<Leader>gl', '<Cmd>Pick git_commits<CR>', 'Log')
map('<Leader>gh', '<Cmd>Pick git_hunks<CR>', 'Hunks')

-- ============================ Terminal / AI ============================
map('<Leader>tt', '<Cmd>botright 15split | terminal<CR>', 'Terminal')
map('<Leader>ac', '<Cmd>botright vsplit | terminal claude<CR>', 'Claude Code')
map('<Leader>ao', '<Cmd>botright vsplit | terminal opencode<CR>', 'opencode')
vim.keymap.set('t', '<Esc><Esc>', [[<C-\><C-n>]], { desc = 'Exit terminal mode' })
vim.api.nvim_create_autocmd('TermOpen', { command = 'setlocal nonumber norelativenumber | startinsert' })

-- ============================ Treesitter ============================
vim.g.ts_langs = {
  'bash', 'css', 'diff', 'dockerfile', 'embedded_template', 'git_config',
  'html', 'javascript', 'jsdoc', 'json', 'lua', 'luadoc', 'markdown', 'markdown_inline',
  'query', 'regex', 'ruby', 'sql', 'toml', 'tsx', 'typescript', 'vim', 'vimdoc', 'yaml',
}
if #vim.api.nvim_list_uis() > 0 then
  require('nvim-treesitter').install(vim.g.ts_langs, { max_jobs = 1 }) -- async; no-op when installed
end
vim.api.nvim_create_autocmd('FileType', {
  callback = function(ev)
    if pcall(vim.treesitter.start, ev.buf) then
      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

-- ============================ LSP ============================
-- Servers are installed by mise (see ~/.config/mise/config.toml)
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
    local buf = function(lhs, rhs, desc, mode)
      vim.keymap.set(mode or 'n', lhs, rhs, { buffer = ev.buf, desc = desc })
    end
    buf('gd', vim.lsp.buf.definition, 'Definition')
    buf('gD', vim.lsp.buf.declaration, 'Declaration')
    buf('<Leader>la', vim.lsp.buf.code_action, 'Code action', { 'n', 'x' })
    buf('<Leader>lr', vim.lsp.buf.rename, 'Rename')
    buf('<Leader>lf', function() vim.lsp.buf.format({ async = true }) end, 'Format', { 'n', 'x' })
    buf('<Leader>lR', '<Cmd>Pick lsp scope="references"<CR>', 'References')
    buf('<Leader>ld', vim.diagnostic.open_float, 'Line diagnostics')
    buf('<Leader>li', function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
    end, 'Toggle inlay hints')
  end,
})
