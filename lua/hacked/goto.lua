local M = {}
local H = {}

local fs = require("hacked._private.files")

local LOCATION = "~/.cache/nvim/hacked-goto"
local FILE = "_gotos.txt"

--- @class hacked.goto.File
--- @field path string
--- @field cl integer cursor line

--- @return string
local filepath = function()
    return vim.fn.expand(LOCATION .. "/" .. vim.fn.fnamemodify("", ":p:h"):gsub("/", "_") .. FILE)
end

--- @param line string
--- @return hacked.goto.File|nil
local parse_line = function(line)
    local path, cl = string.match(line, "^(.-):(%d+)$")
    if path and cl then
        return { path = path, cl = cl }
    end
end

--- add the current buffer to the file list
M.add = function()
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ~= "" then
        vim.notify("cannot add invalid buffer", vim.log.levels.WARN, {})
        return
    end
    local name = vim.api.nvim_buf_get_name(bufnr)
    local fpath = vim.fn.fnamemodify(name, ":p:.")
    local cl = vim.fn.getpos(".")[2]
    fs.append_line(filepath(), string.format("%s:%d", fpath, cl))
end

--- goto the provided index and open in the corresponding window
--- @param file hacked.goto.File|nil
--- @param winr integer
H.open = function(file, winr)
    if file == nil then
        return
    end
    vim.api.nvim_set_current_win(winr)

    local bufs = vim.api.nvim_list_bufs()
    local bufnr = vim.iter(bufs):find(function(buf)
        local name = vim.api.nvim_buf_get_name(buf)
        local fpath = vim.fn.fnamemodify(name, ":p:.")
        return fpath == file.path
    end)

    if bufnr ~= nil then
        vim.api.nvim_win_set_buf(winr, bufnr)
    else
        vim.cmd("edit " .. file.path)
    end
    vim.cmd(string.format("normal! %dggzz", file.cl))
end

--- quickly open a specific saved goto
--- @param i integer 1 based index
M.quick_open = function(i)
    local content, _ = fs.read(filepath())
    if content ~= nil then
        local lines = vim.split(content, "\n")
        local line = lines[i]
        if line ~= nil then
            local file = parse_line(line)
            H.open(file, 0)
        else
            vim.notify("invalid position", vim.log.levels.WARN, {})
        end
    end
end

--- open an editable float
M.menu = function()
    local winr = vim.api.nvim_get_current_win()
    local editor_width = vim.o.columns
    local editor_height = vim.o.lines
    local width = math.floor(0.5 * editor_width)
    local height = math.floor(0.32 * editor_height)
    local row = (editor_height - height) / 2
    local col = (editor_width - width) / 2

    local float_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_open_win(float_buf, true, {
        title = vim.fn.fnamemodify("", ":p:h"),
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
    })

    vim.cmd("edit " .. filepath())

    vim.api.nvim_create_autocmd({ "BufWritePost" }, {
        buffer = float_buf,
        group = vim.api.nvim_create_augroup("hacked.goto.notif", { clear = true }),
        callback = function()
            vim.notify("saved!")
        end,
    })

    vim.keymap.set("n", "<enter>", function()
        local line = vim.api.nvim_get_current_line()
        local file = parse_line(line)
        H.open(file, winr)
        if vim.api.nvim_buf_is_valid(float_buf) then
            vim.api.nvim_buf_delete(float_buf, { force = true })
        end
    end, { buffer = float_buf })

    vim.keymap.set("n", "q", function()
        if vim.api.nvim_buf_is_valid(float_buf) then
            vim.api.nvim_buf_delete(float_buf, { force = true })
        end
    end, { buffer = float_buf })
end

M.setup = function()
    local dir = vim.fn.expand(LOCATION)
    if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
    end
end

return M
