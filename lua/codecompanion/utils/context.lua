local api = vim.api

local M = {}

local ESC_FEEDKEY = api.nvim_replace_termcodes("<ESC>", true, false, true)

---@param bufnr nil|integer
---@return string
M.get_filetype = function(bufnr)
  bufnr = bufnr or 0
  local ft = api.nvim_buf_get_option(bufnr, "filetype")

  if ft == "cpp" then
    return "C++"
  end

  return ft
end

---@param mode string
---@return boolean
local function is_visual_mode(mode)
  return mode == "v" or mode == "V" or mode == "^V"
end

---@param mode string
---@return boolean
local function is_normal_mode(mode)
  return mode == "n" or mode == "no" or mode == "nov" or mode == "noV" or mode == "no"
end

---@param bufnr nil|integer
---@return table,number,number,number,number
function M.get_visual_selection(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- store the current mode
  local mode = vim.fn.mode()

  -- if we're not in visual mode, we need to re-enter it briefly
  if mode ~= "v" and mode ~= "v" and mode ~= "" then
    vim.cmd("normal! gv")
  end

  -- now we can get the positions
  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")

  -- exit visual mode
  if mode ~= "v" and mode ~= "v" and mode ~= "" then
    vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<esc>", true, false, true))
  end

  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]

  -- normalize the range to start < end
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  -- handle partial lines
  if #lines == 1 then
    lines[1] = lines[1]:sub(start_col, end_col)
  else
    lines[1] = lines[1]:sub(start_col)
    lines[#lines] = lines[#lines]:sub(1, end_col)
  end

  return lines, start_line, start_col, end_line, end_col
end

---Get the context of the current buffer.
---@param bufnr? integer
---@param args? table
---@return table
function M.get(bufnr, args)
  bufnr = bufnr or api.nvim_get_current_buf()
  local winnr = api.nvim_get_current_win()
  local mode = vim.fn.mode()
  local cursor_pos = api.nvim_win_get_cursor(winnr)

  local lines, start_line, start_col, end_line, end_col = {}, cursor_pos[1], cursor_pos[2], cursor_pos[1], cursor_pos[2]

  local is_visual = false
  local is_normal = true

  if args and args.range and args.range > 0 then
    is_visual = true
    is_normal = false
    mode = "v"
    lines, start_line, start_col, end_line, end_col = M.get_visual_selection(bufnr)
  elseif is_visual_mode(mode) then
    is_visual = true
    is_normal = false
    lines, start_line, start_col, end_line, end_col = M.get_visual_selection(bufnr)
  end

  -- Consider adjustment here for is_normal if there are scenarios where it doesn't align appropriately

  return {
    winnr = winnr,
    bufnr = bufnr,
    mode = mode,
    is_visual = is_visual,
    is_normal = is_normal,
    buftype = api.nvim_buf_get_option(bufnr, "buftype") or "",
    filetype = M.get_filetype(bufnr),
    filename = api.nvim_buf_get_name(bufnr),
    cursor_pos = cursor_pos,
    lines = lines,
    start_line = start_line,
    start_col = start_col,
    end_line = end_line,
    end_col = end_col,
  }
end

return M
