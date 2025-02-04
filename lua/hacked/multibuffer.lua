local M = {}

local PREVIEW_SIZE = 9

--- BUG: scroll height affects placement of windows...

-- vim.lsp.buf.references(nil, {on_list = function(opts) vim.print(opts) end})
-- TODO: perfect enhancement I can make to my multibuffer
-- but I actually need to make it better
-- probably a centered float that displays one at a time
-- but I can tab through it?
-- easier to handle refreshing if I did it that way too!

--- @class hacked.multibuffer.Entry
--- @field bufnr integer
--- @field lnum integer
--- @field msg string
--- @field fp string filepath

--- @alias hacked.multibuffer.Type "diagnostics"|"quickfix"

local OFFSET = 3

--- @param bufnr integer
--- @param position integer
--- @return table<string>
local preview = function(bufnr, position)
    local lines = vim.api.nvim_buf_get_lines(bufnr, math.max(position - OFFSET, 0), position + OFFSET + 1, false)
    local language = vim.bo[bufnr].filetype
    table.insert(lines, 1, string.format("```%s", language))
    while #lines < (PREVIEW_SIZE - 1) do
        table.insert(lines, "")
    end
    table.insert(lines, #lines + 1, "```")
    return lines
end

--- @param message string
--- @param file string
--- @param type hacked.multibuffer.Type
local header = function(message, file, type)
    if type == "diagnostics" then
        return { { "  " .. message, "MiniStatuslineModeReplace" }, { "  " .. file, "Comment" } }
    else
        return { { "  " .. message, "MiniStatuslineModeNormal" }, { "  " .. file, "Comment" } }
    end
end

--- @class hacked.multibuffer.DrawOpts
--- @field bufnr integer
--- @field winr integer

-- TODO: move M.draw to it's own module

--- @param entries table<hacked.multibuffer.Entry>
--- @param type hacked.multibuffer.Type
--- @param opts hacked.multibuffer.DrawOpts|nil
M.draw = function(entries, type, opts)
    opts = opts or {}
    local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
    local winr = opts.winr or vim.api.nvim_get_current_win()
    vim.wo[winr].conceallevel = 1
    vim.bo[bufnr].filetype = "markdown"
    local ns = vim.api.nvim_create_namespace("hacked.multibuffer." .. type)
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    local group = vim.api.nvim_create_augroup("hacked.multibuffer" .. type, { clear = true })
    for i, entry in ipairs(entries) do
        if type == "diagnostics" then
            vim.api.nvim_create_autocmd({ "BufWritePost" }, {
                buffer = entry.bufnr,
                group = group,
                callback = function(ev)
                    if
                        ev.buf == entry.bufnr
                        and vim.api.nvim_buf_is_valid(bufnr)
                        and vim.api.nvim_win_is_valid(winr)
                    then
                        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
                        M.draw(M.diagnostic_entries(), type, { bufnr = bufnr, winr = winr })
                    end
                end,
            })
        end

        local offset = (i - 1) * PREVIEW_SIZE
        local content = preview(entry.bufnr, entry.lnum)
        vim.api.nvim_buf_set_lines(bufnr, offset, offset + 1, false, content)
        vim.api.nvim_buf_set_extmark(bufnr, ns, offset, 0, {
            virt_text = header(entry.msg, entry.fp, type),
            virt_lines_above = true,
            virt_lines = i > 1 and { { { string.rep("─", 1000), "Comment" } } } or nil,
            virt_text_pos = "overlay",
        })
    end

    vim.keymap.set("n", "<enter>", function()
        local cursor = vim.fn.getpos(".")[2]
        local editing = math.ceil(cursor / PREVIEW_SIZE)
        if entries[editing] then
            local entry = entries[editing]
            local top_win_ln = vim.fn.getpos("w0")[2]
            local _winr = vim.api.nvim_open_win(entry.bufnr, true, {
                border = "none",
                relative = "win",
                row = ((editing - 1) * PREVIEW_SIZE) - top_win_ln + editing + 1,
                col = 0,
                height = 7,
                width = vim.api.nvim_win_get_width(0),
                zindex = 1,
            })

            vim.wo[_winr].winbar = ""
            vim.wo[_winr].scroll = 0
            vim.wo[_winr].scrolloff = 0
            vim.api.nvim_command(string.format("normal! %dgg", entry.lnum + 1))
            vim.api.nvim_command("normal! zz")
        end
    end, { desc = "hacked: open mini-buffer", buffer = bufnr })
end

--- @param entries table<hacked.multibuffer.Entry>
--- @param type hacked.multibuffer.Type
local open = function(entries, type)
    vim.cmd("tabnew")
    M.draw(entries, type)
end

--- @return table<hacked.multibuffer.Entry>
M.quickfix_entries = function()
    local quickfix_list = vim.fn.getqflist()
    local entries = {}
    for _, item in ipairs(quickfix_list) do
        if item.bufnr then
            local name = vim.api.nvim_buf_get_name(item.bufnr)
            local path = vim.fn.fnamemodify(name, ":~:.")
            table.insert(entries, {
                bufnr = item.bufnr,
                lnum = item.lnum - 1, -- lnum is 1-based, convert to 0-based
                msg = item.text,
                fp = path,
            })
        end
    end

    return entries
end

M.quickfix = function()
    open(M.quickfix_entries(), "quickfix")
end

--- @return table<hacked.multibuffer.Entry>
M.diagnostic_entries = function()
    local diagnostics = vim.diagnostic.get(nil, { severity = "ERROR" })
    local entries = {}
    for _, diagnostic in ipairs(diagnostics) do
        if diagnostic.bufnr then
            local name = vim.api.nvim_buf_get_name(diagnostic.bufnr)
            local path = vim.fn.fnamemodify(name, ":~:.")
            table.insert(entries, {
                bufnr = diagnostic.bufnr,
                lnum = diagnostic.lnum,
                msg = diagnostic.message,
                fp = path,
            })
        end
    end
    return entries
end

M.diagnostics = function()
    open(M.diagnostic_entries(), "diagnostics")
end

return M
