local M = {}

--- @param bufnr integer
--- @return string
M.extension = function(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    local path = vim.fn.fnamemodify(name, ":~:.")
    local segments = vim.split(path, ".")
    if #segments == 0 then
        return ""
    end

    return segments[#segments]
end

--- @return integer,integer
M.active_selection = function()
    local visual_pos = vim.fn.getpos("v")
    local visual_line = visual_pos[2]
    local cursor_pos = vim.fn.getpos(".")
    local cursor_line = cursor_pos[2]
    local start_line = math.min(visual_line, cursor_line)
    local end_line = math.max(visual_line, cursor_line)
    return start_line, end_line
end

--- fill a buffer with n - blank lines
--- @param bufnr integer
--- @param n integer
M.blanks = function(bufnr, n)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(string.rep(" ", n), " "))
end

return M
