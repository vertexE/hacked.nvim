local M = {}

local function draw(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local ns = vim.api.nvim_create_namespace("hacked.todo")
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    for i, line in ipairs(lines) do
        local state = line:match("^%- %[(.)]")
        if state then
            local start_col, end_col = line:find("^%- %[.%]")
            local dist = end_col - start_col
            local col = start_col or 0
            local symbol = state == " " and "" or state == "-" and "" or state == "x" and ""
            vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, col - 1, {
                virt_text = { { string.rep(" ", dist / 2) .. symbol .. string.rep(" ", dist / 2), "TodoFgTODO" } },
                virt_text_pos = "overlay",
            })
        end
    end
end

M.setup = function()
    vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("hacked.todo.attach", { clear = true }),
        pattern = { "*.md" },
        callback = function(ev)
            local win = vim.api.nvim_get_current_win()
            vim.wo[win].number = false

            vim.keymap.set("n", "<enter>", function()
                local line = vim.api.nvim_get_current_line()
                if line:match("^%- %[.%]") then
                    local updated = line:gsub("%[.%]", function(match)
                        if match == "[ ]" then
                            return "[-]"
                        elseif match == "[-]" then
                            return "[x]"
                        elseif match == "[x]" then
                            return "[ ]"
                        end
                    end)
                    vim.api.nvim_set_current_line(updated)
                end
            end, { buffer = ev.buf })
        end,
    })

    vim.api.nvim_create_autocmd("BufLeave", {
        group = vim.api.nvim_create_augroup("hacked.todo.dettach", { clear = true }),
        pattern = { "*.md" },
        callback = function()
            local win = vim.api.nvim_get_current_win()
            vim.wo[win].number = true
        end,
    })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
        group = vim.api.nvim_create_augroup("hacked.todo.draw", { clear = true }),
        pattern = { "*.md" },
        callback = function(ev)
            draw(ev.buf)
        end,
    })
end

return M
