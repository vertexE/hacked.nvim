local M = {}

local files = require("hacked._private.files")

local LOCATION = "~/.cache/nvim/hacked-clipboard"
local FILE = "history.json"
local MAX_CLIPS = 100

--- @class hacked.clipboard.Yank
--- @field content string
--- @field ft string

--- @type table<hacked.clipboard.Yank>
local yanks = {}
local loaded = false

local load = function()
    local content = files.read(vim.fn.expand(LOCATION) .. "/" .. FILE)
    if content ~= nil then
        --- @type table<hacked.clipboard.Yank>
        yanks = vim.fn.json_decode(content)
    end
    loaded = true
end

local save = function()
    local raw = vim.fn.json_encode(yanks)
    local err = files.write(vim.fn.expand(LOCATION) .. "/" .. FILE, raw)
    if err ~= nil then
        vim.notify("failed to persist clipboard history", vim.log.levels.ERROR, {})
    end
end

--- @return table<hacked.clipboard.Yank>
M.list = function()
    return yanks
end

M.setup = function()
    vim.schedule(load)
    vim.api.nvim_create_autocmd({ "TextYankPost" }, {
        group = vim.api.nvim_create_augroup("hacked.clipboard.yank", { clear = true }),
        pattern = "*",
        callback = function(ev)
            if not loaded then
                return -- skip this, unlikely to happen
            end
            if vim.v.event.operator == "d" then -- do not track deletes
                return
            end
            if #yanks == MAX_CLIPS then
                table.remove(yanks, #yanks)
            end
            table.insert(yanks, 1, {
                content = vim.fn.getreg('"'),
                ft = vim.bo[ev.buf].filetype,
            })
            vim.schedule(save)
        end,
    })
    local dir = vim.fn.expand(LOCATION)
    if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
    end
end

return M
