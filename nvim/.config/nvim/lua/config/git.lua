local util = require('config.util')
local map, cmd, pick = util.map, util.cmd, util.pick

require('mini.git').setup()
require('mini.diff').setup({ view = { style = 'sign' } })

map('<Leader>gs', function() MiniGit.show_at_cursor() end, 'Show at cursor')
map('<Leader>gd', function() MiniDiff.toggle_overlay() end, 'Diff overlay')
map('<Leader>gb', cmd('vertical Git blame -- %'), 'Blame')
map('<Leader>gl', pick('git_commits'), 'Log')
map('<Leader>gh', pick('git_hunks'), 'Hunks')
