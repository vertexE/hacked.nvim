local M = {}

-- Add the plugin directory to the runtime path
local files = require("hacked._private.files")

--- @class hacked.executor.Executor
--- @field runner string
--- @field extension string

--- @type table<string,hacked.executor.Executor>
local language_map = {
    go = {
        runner = "go run",
        extension = "go",
    },
    python = {
        runner = "python3",
        extension = "py",
    },
    javascript = {
        runner = "node",
        extension = "js",
    },
}

--- @param block hacked.executor.CodeBlock
local run_block = function(block)
    if not language_map[block.language] then
        vim.notify("unsupported language", vim.log.levels.ERROR, {})
        return
    end

    local tmpfile = "/tmp/hacked_executor_" .. os.time() .. "." .. language_map[block.language].extension
    local lines = vim.api.nvim_buf_get_lines(0, block._start, block._end - 1, false)
    files.write(tmpfile, table.concat(lines, "\n"))

    local exec = {}
    for _, arg in ipairs(vim.split(language_map[block.language].runner, " ")) do
        table.insert(exec, arg)
    end
    table.insert(exec, tmpfile)

    vim.system(exec, { text = true }, function(ev)
        vim.schedule(function()
            local bufnr = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_open_win(bufnr, false, {
                split = "below",
                height = 10,
            })
            vim.print(ev)
            if #ev.stdout > 0 then
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(ev.stdout, "\n"))
            elseif #ev.stderr > 0 then
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(ev.stderr, "\n"))
            end
        end)
    end)
end

--- @class hacked.executor.CodeBlock
--- @field language string
--- @field _start integer
--- @field _end integer

--- @param bufnr integer
--- @return hacked.executor.CodeBlock|nil
local get_code_block = function(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local cursor_pos = vim.fn.getpos(".")[2]
    local language
    local _start = 0
    local _end = 0
    if string.find(lines[cursor_pos], "```(%a+)") then
        language = string.match(lines[cursor_pos], "```(%a+)")
        _start = cursor_pos
    else
        return
    end

    for i = cursor_pos + 1, #lines do
        if string.find(lines[i], "```") then
            _end = i
            break
        end
    end

    return {
        language = language,
        _start = _start,
        _end = _end,
    }
end

local draw_executors = function(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    local positions = {}
    for i, line in ipairs(lines) do
        if string.find(line, "```(%a+)") then
            table.insert(positions, i)
        end
    end

    local ns = vim.api.nvim_create_namespace("hacked.executor.run")
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    for _, position in ipairs(positions) do
        vim.api.nvim_buf_set_extmark(bufnr, ns, position - 1, 0, {
            virt_text = { { "  run", "TodoFgTODO" } },
            virt_text_pos = "eol",
        })
    end
end

M.setup = function()
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
        pattern = "*.md",
        callback = function(ev)
            draw_executors(ev.buf)
        end,
    })

    vim.api.nvim_create_autocmd({ "BufEnter" }, {
        pattern = "*.md",
        callback = function(ev)
            vim.keymap.set("n", "<enter>", function()
                local block = get_code_block(ev.buf)
                if block then
                    run_block(block)
                else
                    vim.notify("not a code block", vim.log.levels.WARN, {})
                end
            end, { desc = "", buffer = ev.buf })
        end,
    })
end

return M
