local util = require('config.util')
local map = util.map

-- move: Alt-h/j/k/l   splitjoin: gS   surround: sa/sd/sr   snippets: <C-j>
util.mini('ai', 'align', 'bracketed', 'bufremove', 'jump', 'move', 'pairs', 'splitjoin', 'surround', 'misc', 'completion')
MiniMisc.setup_restore_cursor()
MiniMisc.setup_auto_root()

local snippets = require('mini.snippets')
snippets.setup({ snippets = { snippets.gen_loader.from_lang() } })

local insert_expr = { mode = 'i', expr = true }
map('<Tab>', [[pumvisible() ? "\<C-n>" : "\<Tab>"]], 'Next completion', insert_expr)
map('<S-Tab>', [[pumvisible() ? "\<C-p>" : "\<S-Tab>"]], 'Previous completion', insert_expr)
map('<CR>', function()
  if vim.fn.complete_info()['selected'] ~= -1 then return '\25' end -- <C-y>
  return MiniPairs.cr()
end, 'Accept completion or newline', { mode = 'i', expr = true, replace_keycodes = false })
