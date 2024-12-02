vim.cmd([[let &rtp.=','.getcwd()]])

vim.cmd("set rtp+=./deps/plenary")
vim.cmd("set rtp+=./deps/treesitter")

local required_parsers = { "lua", "markdown", "markdown_inline", "yaml" }
local installed_parsers = require("nvim-treesitter.info").installed_parsers()
local to_install = vim.tbl_filter(function(parser)
  return not vim.tbl_contains(installed_parsers, parser)
end, required_parsers)

if #to_install > 0 then
  -- fixes 'pos_delta >= 0' error - https://github.com/nvim-lua/plenary.nvim/issues/52
  vim.cmd("set display=lastline")
  -- make "TSInstall*" available
  vim.cmd("runtime! plugin/nvim-treesitter.vim")
  vim.cmd("TSInstallSync " .. table.concat(to_install, " "))
end