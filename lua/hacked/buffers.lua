local M = {}
local H = {}

--- @class hacked.buffers.Options
--- @field icons ?{active?: string, inactive?: string, modified?: string}

--- @type hacked.buffers.Options
local opts = {
    icons = {
        active = "󰡖 ",
        inactive = " ",
        modified = " ",
    },
}

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

--- @param float_bufnr integer
--- @param active_bufnr integer
--- @param winr integer
H.draw = function(float_bufnr, active_bufnr, winr)
    local ns = vim.api.nvim_create_namespace("hacked.buffers")
    -- clear the buffer
    vim.api.nvim_buf_set_lines(float_bufnr, 0, -1, false, {})
    vim.api.nvim_buf_clear_namespace(float_bufnr, ns, 0, -1)

    local buffers = list_buffers()
    vim.keymap.set("n", "<enter>", function()
        local cursor = vim.fn.getpos(".")[2]
        local _bufnr = buffers[cursor].bufnr
        vim.api.nvim_set_current_win(winr)
        vim.api.nvim_set_current_buf(_bufnr)
        H.draw(float_bufnr, _bufnr, winr)
    end, { buffer = float_bufnr })
    vim.keymap.set("n", "dd", function()
        local cursor = vim.fn.getpos(".")[2]
        local _bufnr = buffers[cursor].bufnr
        if vim.api.nvim_buf_is_loaded(_bufnr) then
            vim.api.nvim_buf_delete(_bufnr, { force = true })
        end
        H.draw(float_bufnr, active_bufnr, winr)
    end, { buffer = float_bufnr })

    vim.keymap.set("n", "q", function()
        if vim.api.nvim_buf_is_loaded(float_bufnr) then
            vim.api.nvim_buf_delete(float_bufnr, { force = true })
        end
    end, { buffer = float_bufnr })

    local offset = vim.iter(buffers)
        :map(function(_buffer)
            return #tostring(_buffer.bufnr)
        end)
        :fold({}, function(acc, v)
            acc.max = math.max(v, acc.max or v)
            return acc
        end).max

    for i, _buffer in ipairs(buffers) do
        local active = _buffer.bufnr == active_bufnr
        local modified = vim.bo[_buffer.bufnr].modified and opts.icons.modified or ""
        local bufnr_s = tostring(_buffer.bufnr)
        local symbol = active and opts.icons.active or opts.icons.inactive
        vim.api.nvim_buf_set_lines(float_bufnr, i - 1, i, false, {
            " "
                .. symbol
                .. string.rep(" ", (offset - #bufnr_s) or 0)
                .. " "
                .. bufnr_s
                .. " "
                .. _buffer.name
                .. " "
                .. modified,
        })
        vim.api.nvim_buf_set_extmark(float_bufnr, ns, i - 1, 1, {
            virt_text = {
                {
                    symbol .. string.rep(" ", (offset - #bufnr_s) or 0) .. " " ..  bufnr_s,
                    active and "Boolean" or "Comment",
                },
                { " " .. _buffer.name, "String" },
                { " " .. modified, "DiagnosticOk" },
            },
            virt_text_pos = "overlay",
        })
    end
end

local float_bufnr = -1
local float_winr = -1

M.open = function()
    if vim.api.nvim_win_is_valid(float_winr) and vim.api.nvim_buf_is_valid(float_bufnr) then
        vim.api.nvim_win_close(float_winr, true)
        vim.api.nvim_buf_delete(float_bufnr, { force = true })
        return
    end

    local winr = vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_get_current_buf()
    local win_width = vim.api.nvim_win_get_width(winr)
    local width = math.ceil(win_width * 0.2)

    float_bufnr = vim.api.nvim_create_buf(false, true)
    float_winr = vim.api.nvim_open_win(float_bufnr, true, {
        win = winr,
        width = width,
        split = "left",
        style = "minimal",
    })

    H.draw(float_bufnr, bufnr, winr)
    vim.api.nvim_create_autocmd({ "BufEnter", "BufModifiedSet" }, {
        group = vim.api.nvim_create_augroup("hacked.buffers", { clear = true }),
        callback = function(ev)
            if vim.api.nvim_win_is_valid(float_winr) and vim.api.nvim_buf_is_valid(float_bufnr) then
                H.draw(float_bufnr, ev.buf, winr)
            end
        end,
    })
end

--- @param options ?hacked.buffers.Options
M.setup = function(options)
    options = options or {}
    if options.icons then
        opts.icons.active = options.icons.active or opts.icons.active
        opts.icons.inactive = options.icons.inactive or opts.icons.inactive
        opts.icons.modified = options.icons.modified or opts.icons.modified
    end
    vim.api.nvim_create_user_command("HackedBufferList", function()
        M.open()
    end, {})
end

return M
