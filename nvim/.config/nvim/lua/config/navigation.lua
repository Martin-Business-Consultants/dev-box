local util = require('config.util')
local map, cmd, pick = util.map, util.cmd, util.pick

require('mini.files').setup({ windows = { preview = true, width_preview = 60 } })
util.mini('pick', 'extra', 'visits')
vim.ui.select = MiniPick.ui_select

map('<Leader>e', function() MiniFiles.open(vim.api.nvim_buf_get_name(0)) end, 'Explorer (file)')
map('<Leader>E', function() MiniFiles.open() end, 'Explorer (cwd)')
map('<Leader><Space>', pick('files'), 'Find files')
map('<Leader>/', pick('grep_live'), 'Grep')

map('<Leader>ff', pick('files'), 'Files')
map('<Leader>fg', pick('grep_live'), 'Grep live')
map('<Leader>fw', pick('grep pattern="<cword>"'), 'Grep word')
map('<Leader>fb', pick('buffers'), 'Buffers')
map('<Leader>fh', pick('help'), 'Help')
map('<Leader>fr', pick('resume'), 'Resume')
map('<Leader>fo', pick('oldfiles'), 'Recent files')
map('<Leader>fv', pick('visit_paths'), 'Visited paths')
map('<Leader>fd', pick('diagnostic'), 'Diagnostics')
map('<Leader>fk', pick('keymaps'), 'Keymaps')
map('<Leader>fc', pick('commands'), 'Commands')
map('<Leader>fs', pick('lsp scope="document_symbol"'), 'Symbols (buffer)')
map('<Leader>fS', pick('lsp scope="workspace_symbol"'), 'Symbols (workspace)')

map('<Leader>bd', function() MiniBufremove.delete() end, 'Delete buffer')
map('<Leader>bo', cmd('%bd|e#|bd#'), 'Delete other buffers')
map('<Leader>w', cmd('write'), 'Write')
map('<Leader>q', cmd('quit'), 'Quit')
map('<Esc>', cmd('nohlsearch'), 'Clear search')
