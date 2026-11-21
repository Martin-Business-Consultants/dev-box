local util = require('config.util')
local map, cmd = util.map, util.cmd

map('<Leader>tt', cmd('botright 15split | terminal'), 'Terminal')
map('<Leader>ac', cmd('botright vsplit | terminal claude'), 'Claude Code')
map('<Leader>ao', cmd('botright vsplit | terminal opencode'), 'opencode')
map('<Esc><Esc>', [[<C-\><C-n>]], 'Exit terminal mode', { mode = 't' })

vim.api.nvim_create_autocmd('TermOpen', { command = 'setlocal nonumber norelativenumber | startinsert' })
