local M = {}

local buffer = require("hacked._private.buffer")
local fs = require("hacked._private.files")
local git = require("hacked._private.git")

--- @class hacked.portal.State
--- @field pos integer
--- @field blocks table<hacked.portal.Block>

--- @class hacked.portal.Block
--- @field path string
--- @field code string[]
--- @field language string

--- @type hacked.portal.State
local state = {
    blocks = {},
    pos = 1,
}

local CACHE = "~/.cache/nvim/hacked-portal"
local PERSIST_FILE_NAME = "_hacked-portal.json"
local MAX_BLOCKS = 5

local load = function()
    local dir = vim.fn.expand(CACHE)
    local raw, err = fs.read(dir .. "/" .. git.root():gsub("/", "_") .. PERSIST_FILE_NAME)
    if not err then
        state = vim.fn.json_decode(raw)
    end
end

local persist = function()
    vim.schedule(function()
        local dir = vim.fn.expand(CACHE)
        local raw = vim.fn.json_encode(state)
        local err = fs.write(dir .. "/" .. git.root():gsub("/", "_") .. PERSIST_FILE_NAME, raw)
        if err ~= nil then
            vim.notify(err, vim.log.levels.ERROR, {})
            return
        end
    end)
end

--- @param path string
--- @return table<table<string>>
local header = function(path)
    local t = {}
    for i = 1, #state.blocks do
        table.insert(t, { "", i == state.pos and "HackedPortalEdge" or "HackedPortalEdgeNC" })
        table.insert(t, { string.format("%d", i), i == state.pos and "HackedPortal" or "HackedPortalNC" })
        table.insert(t, { "", i == state.pos and "HackedPortalEdge" or "HackedPortalEdgeNC" })
    end
    table.insert(t, { string.rep(" ", 5) .. path, "Comment" })
    return t
end

--- save selection to code blocks
M.save = function()
    if #state.blocks == MAX_BLOCKS then
        vim.notify("cannot save - max saved code blocks", vim.log.levels.WARN, {})
        return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local sel_start, sel_end = buffer.active_selection()
    local lines = vim.api.nvim_buf_get_lines(bufnr, sel_start - 1, sel_end, false)
    local filetype = vim.bo[bufnr].filetype

    local name = vim.api.nvim_buf_get_name(bufnr)
    local path = vim.fn.fnamemodify(name, ":~:.")

    vim.api.nvim_command('normal! "+y')

    table.insert(state.blocks, {
        code = lines,
        language = filetype,
        path = path,
    })
    persist()
end

local portal_winr = nil

--- @param bufnr integer
local draw = function(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        vim.notify("hacked.portal cannot draw content", vim.log.levels.ERROR, {})
        return
    end

    local block = state.blocks[state.pos]
    local ns = vim.api.nvim_create_namespace("hacked.portal")
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    local lines = { unpack(block.code) }
    table.insert(lines, 1, string.format("```%s", block.language))
    table.insert(lines, #lines + 1, "```")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
        virt_text = { unpack(header(block.path)) },
        virt_text_pos = "overlay",
    })

    vim.api.nvim_command("normal! 3gg")
end

M.open = function()
    if #state.blocks == 0 then
        vim.notify("no saved code blocks", vim.log.levels.WARN, {})
        return
    end

    if portal_winr and vim.api.nvim_win_is_valid(portal_winr) then
        vim.api.nvim_set_current_win(portal_winr)
        return
    end
    local winr = vim.api.nvim_get_current_win()
    local win_width = vim.api.nvim_win_get_width(winr)
    local win_height = vim.api.nvim_win_get_height(winr)
    local width = math.ceil(win_width * 0.5)
    local height = math.ceil(win_height * 0.3)

    local float_buf = vim.api.nvim_create_buf(false, true)
    portal_winr = vim.api.nvim_open_win(float_buf, true, {
        relative = "editor",
        row = 1,
        col = 1000,
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
    })
    vim.bo[float_buf].filetype = "markdown"
    vim.wo[portal_winr].conceallevel = 1

    vim.keymap.set("n", "<tab>", function()
        state.pos = (state.pos % #state.blocks) + 1
        draw(float_buf)
    end, { desc = "hacked.portal: next saved code block", buffer = float_buf })
    vim.keymap.set("n", "<s-tab>", function()
        if state.pos == 1 then
            state.pos = #state.blocks
        else
            state.pos = state.pos - 1
        end
        draw(float_buf)
    end, { desc = "hacked.portal: previous saved code block", buffer = float_buf })
    vim.keymap.set("n", "q", function()
        if vim.api.nvim_buf_is_valid(float_buf) then
            vim.api.nvim_buf_delete(float_buf, { force = true })
        end
    end, { desc = "hacked.portal: close float", buffer = float_buf })
    vim.keymap.set("n", "<enter>", function()
        vim.fn.setreg(".", state.blocks[state.pos].code)
    end, { desc = "hacked.portal: copy code block", buffer = float_buf })

    draw(float_buf)
end

M.clear = function()
    state.blocks = {}
    state.pos = 1
    vim.notify("hacked.portal cleared blocks", vim.log.levels.INFO, {})
    persist()
end

--- loadup persisted code blocks
M.setup = function()
    local dir = vim.fn.expand(CACHE)
    if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
    end
    vim.schedule(load)
end

return M
