-- Also read by install.sh's neovim step. gitcommit is omitted: it can't compile in 1GB RAM.
vim.g.ts_langs = {
  'bash', 'css', 'diff', 'dockerfile', 'embedded_template', 'git_config',
  'html', 'javascript', 'jsdoc', 'json', 'lua', 'luadoc', 'markdown', 'markdown_inline',
  'query', 'regex', 'ruby', 'sql', 'toml', 'tsx', 'typescript', 'vim', 'vimdoc', 'yaml',
}

if #vim.api.nvim_list_uis() > 0 then
  require('nvim-treesitter').install(vim.g.ts_langs, { max_jobs = 1 })
end

vim.api.nvim_create_autocmd('FileType', {
  callback = function(ev)
    if pcall(vim.treesitter.start, ev.buf) then
      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})
