local M = {}

--- used for setting highlight groups
--- @param severity vim.diagnostic.Severity
--- @return string
local severity_to_string = function(severity)
    local options = {
        [vim.diagnostic.severity.ERROR] = "Error",
        [vim.diagnostic.severity.WARN] = "Warn",
        [vim.diagnostic.severity.INFO] = "Info",
        [vim.diagnostic.severity.HINT] = "Hint",
    }
    return options[severity]
end

local MAX_DIAGNOSTIC_MSG_LENGTH = 80
local SPACES = 4

--- @param diagnostic vim.Diagnostic
--- @param spaces integer number of spaces to prefix
--- @return table
local format_diagnostic = function(diagnostic, spaces)
    local diagnostic_split = vim.split(diagnostic.message, "\n")
    --- @type string[]
    local lines_limited = {}
    for _, message in ipairs(diagnostic_split) do
        if #message > MAX_DIAGNOSTIC_MSG_LENGTH then
            local remaining = message
            while #remaining > MAX_DIAGNOSTIC_MSG_LENGTH do
                local pos = string.find(remaining, " ", MAX_DIAGNOSTIC_MSG_LENGTH)
                if pos ~= nil then
                    local limited = string.sub(remaining, 0, pos)
                    table.insert(lines_limited, limited)
                else
                    -- no more whitespace could be found
                    break
                end
                remaining = string.sub(remaining, pos)
            end
            if #remaining > 0 then
                table.insert(lines_limited, remaining)
            end
        else
            table.insert(lines_limited, message)
        end
    end

    local lines = {}
    for i, message in ipairs(lines_limited) do
        local symbol
        if i == 1 then
            symbol = "󱞽"
        else
            symbol = "│"
        end
        local msg = string.format("%s%s %s", string.rep(" ", spaces), symbol, message)
        table.insert(lines, { { msg, "Diagnostic" .. severity_to_string(diagnostic.severity) } })
    end

    return lines
end

local show_virtual_text_diagnostics = function()
    local ns = vim.api.nvim_create_namespace("hacked.diagnostics.diagnostic")
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

    local diagnostics = vim.diagnostic.get(bufnr, { lnum = cursor_line, severity = vim.diagnostic.severity.ERROR })
    if #diagnostics == 0 then
        return
    end
    local virt_lines = {}
    for _, diagnostic in ipairs(diagnostics) do
        local lines = format_diagnostic(diagnostic, SPACES + diagnostic.col)
        for _, line in ipairs(lines) do
            table.insert(virt_lines, line)
        end
    end
    local diagnostic = diagnostics[1]
    vim.api.nvim_buf_set_extmark(bufnr, ns, diagnostic.lnum, 0, {
        virt_lines = virt_lines,
        virt_text_pos = "eol",
    })
end

-- TODO: add opts for which diagnostics to show + symbols, spacing, etc
M.setup = function()
    vim.api.nvim_create_autocmd({ "DiagnosticChanged", "CursorMoved" }, {
        pattern = {
            "*.c",
            "*.h",
            "*.ts",
            "*.js",
            "*.tsx",
            "*.jsx",
            "*.rs",
            "*.go",
            "*.py",
            "*.css",
            "*.scss",
            "*.vue",
            "*.html",
            "*.json",
            "*.java",
            "*.lua",
            "*.zig",
        },
        callback = show_virtual_text_diagnostics,
    })
end

return M
