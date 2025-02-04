local M = {}

--- @class hacked.buffers.Buffer
--- @field bufnr integer
--- @field name string
--- @field path string

--- @return table<hacked.buffers.Buffer>
local list_buffers = function()
    local buffers = {}
    local cmd = vim.api.nvim_exec2("ls", { output = true })
    local output = vim.split(cmd.output, "\n")
    for _, line in ipairs(output) do
        local buf = string.match(line, "%d+")
        local bufnr = tonumber(vim.trim(buf))
        if bufnr then
            local full_path = vim.api.nvim_buf_get_name(bufnr)
            local relative = vim.fn.fnamemodify(full_path, ":~:.")
            local file = vim.fn.fnamemodify(full_path, ":t")
            if #file > 0 then
                table.insert(buffers, {
                    bufnr = bufnr,
                    name = file,
                    path = relative,
                })
            end
        end
    end
    return buffers
end

M.open = function()
    local winr = vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_get_current_buf()
    local win_width = vim.api.nvim_win_get_width(winr)
    local win_height = vim.api.nvim_win_get_height(winr)
    local width = math.ceil(win_width * 0.4)
    local height = math.ceil(win_height * 0.2)

    local buffers = list_buffers()
    local float_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_open_win(float_buf, true, {
        title = "buffers",
        relative = "editor",
        row = 0,
        col = 0,
        width = width,
        height = height,
        style = "minimal",
        border = "single",
    })
    vim.keymap.set("n", "<enter>", function()
        local cursor = vim.fn.getpos(".")[2]
        local _bufnr = buffers[cursor].bufnr
        vim.api.nvim_set_current_win(winr)
        vim.api.nvim_set_current_buf(_bufnr)
        if vim.api.nvim_buf_is_loaded(float_buf) then
            vim.api.nvim_buf_delete(float_buf, { force = true })
        end
    end, { buffer = float_buf })

    vim.keymap.set("n", "q", function()
        if vim.api.nvim_buf_is_loaded(float_buf) then
            vim.api.nvim_buf_delete(float_buf, { force = true })
        end
    end, { buffer = float_buf })

    local ns = vim.api.nvim_create_namespace("hacked.buffers")
    vim.api.nvim_buf_clear_namespace(float_buf, ns, 0, -1)
    for i, _buffer in ipairs(buffers) do
        local active = _buffer.bufnr == bufnr
        local symbol = active and "  " or "  "
        vim.api.nvim_buf_set_lines(float_buf, i - 1, i, false, {
            " " .. symbol .. tostring(_buffer.bufnr) .. " " .. _buffer.name .. " " .. _buffer.path,
        })
        vim.api.nvim_buf_set_extmark(float_buf, ns, i - 1, 1, {
            virt_text = {
                { symbol .. tostring(_buffer.bufnr), active and "Boolean" or "Comment" },
                { " " .. _buffer.name, "String" },
                { " " .. _buffer.path, "Comment" },
            },
            virt_text_pos = "overlay",
        })
    end

    vim.bo[float_buf].modifiable = false
end

M.setup = function()
    vim.api.nvim_create_user_command("HackedBufferList", function()
        M.open()
    end, {})
end

return M
