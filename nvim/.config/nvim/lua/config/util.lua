local M = {}

-- map(lhs, rhs, desc, { mode = 'n', buffer = ..., expr = ... })
function M.map(lhs, rhs, desc, opts)
  opts = vim.tbl_extend('force', { desc = desc }, opts or {})
  local mode = opts.mode or 'n'
  opts.mode = nil
  vim.keymap.set(mode, lhs, rhs, opts)
end

function M.cmd(command) return '<Cmd>' .. command .. '<CR>' end

function M.pick(args) return M.cmd('Pick ' .. args) end

-- Set up mini modules that need no options.
function M.mini(...)
  for _, name in ipairs({ ... }) do require('mini.' .. name).setup() end
end

return M
