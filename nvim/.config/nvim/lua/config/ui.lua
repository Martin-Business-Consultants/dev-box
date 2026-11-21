local util = require('config.util')

util.mini('icons', 'notify', 'statusline', 'tabline', 'starter', 'cursorword', 'trailspace')
MiniIcons.mock_nvim_web_devicons()
vim.notify = MiniNotify.make_notify()
if not pcall(vim.cmd.colorscheme, 'miniwinter') then vim.cmd.colorscheme('default') end

require('mini.sessions').setup({ autowrite = true })

local indentscope = require('mini.indentscope')
indentscope.setup({ draw = { animation = indentscope.gen_animation.none() } })

local hipatterns = require('mini.hipatterns')
local highlighters = { hex_color = hipatterns.gen_highlighter.hex_color() }
for _, word in ipairs({ 'FIXME', 'HACK', 'TODO', 'NOTE' }) do
  local name = word:sub(1, 1) .. word:sub(2):lower()
  highlighters[name:lower()] = { pattern = '%f[%w]()' .. word .. '()%f[%W]', group = 'MiniHipatterns' .. name }
end
hipatterns.setup({ highlighters = highlighters })

local triggers = {}
for keys, modes in pairs({
  ['<Leader>'] = 'nx', g = 'nx', z = 'nx', ["'"] = 'nx', ['`'] = 'nx', ['"'] = 'nx',
  ['<C-r>'] = 'ic', ['<C-x>'] = 'i', ['<C-w>'] = 'n', ['['] = 'n', [']'] = 'n',
}) do
  for mode in modes:gmatch('.') do table.insert(triggers, { mode = mode, keys = keys }) end
end

local miniclue = require('mini.clue')
local clues = {
  miniclue.gen_clues.builtin_completion(),
  miniclue.gen_clues.g(),
  miniclue.gen_clues.marks(),
  miniclue.gen_clues.registers(),
  miniclue.gen_clues.windows(),
  miniclue.gen_clues.z(),
}
for key, group in pairs({ a = 'AI', b = 'Buffer', f = 'Find', g = 'Git', l = 'LSP', t = 'Terminal' }) do
  table.insert(clues, { mode = 'n', keys = '<Leader>' .. key, desc = '+' .. group })
end

miniclue.setup({ triggers = triggers, clues = clues, window = { delay = 300 } })
