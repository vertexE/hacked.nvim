local M = {}
local H = {}

--- @class hacked.git.Context
--- @field prev_winr integer the previous win before opening git status

--- @class hacked.git.Config
--- @field actions ?table<string,fun(change:hacked.git.Change, ctx:hacked.git.Context):hacked.git.Change> apply an action on a change mapped by keys

--- @type hacked.git.Config
local config = {
    actions = {},
}

---@param opts ?hacked.git.Config
M.setup = function(opts)
    if opts ~= nil then
        config.actions = opts.actions or config.actions
    end
end

local confirm = require("hacked.confirm")

--- @alias hacked.git.ChangeType "modified"|"renamed"|"added"|"deleted"|"conflict"
--- @alias hacked.git.Stage "staged"|"untracked"|"working"|"partial"

--- @class hacked.git.State
--- @field lines_to_path table<integer,hacked.git.Change> line number in status buf mapping to file path
--- @field winr integer which window the status UI is open in

--- @class hacked.git.Change
--- @field file string
--- @field path string
--- @field stage hacked.git.Stage
--- @field type hacked.git.ChangeType
--- @field depth ?integer

--- @class hacked.git.Dir
--- @field children table<hacked.git.Dir>
--- @field dir string the name of the directory
--- @field path string path to directory (rel)
--- @field depth ?integer
--- @field files table<hacked.git.Change>

--- @type hacked.git.State
local state = {
    lines_to_path = {},
    winr = -1,
}

--- @param node hacked.git.Dir
--- @param dir string
--- @return hacked.git.Dir|nil
local find_child_dir = function(node, dir)
    for _, child in ipairs(node.children) do
        if child.dir == dir then
            return child
        end
    end
    return nil
end

--- parse through a list of hacked.git.Change and create
--- a tree to represent the directory structure.
--- @param changes table<hacked.git.Change>
--- @return hacked.git.Dir
local tree_rep = function(changes)
    local root = {
        path = "",
        dir = "",
        children = {},
        files = {},
    }

    for _, change in ipairs(changes) do
        local node = root
        local segments = vim.split(change.path, "/")
        local rel = ""
        for i, segment in ipairs(segments) do
            rel = rel .. segment .. (i < #segments and "/" or "")
            if i == #segments then -- we made it to the end, insert this segment as the file
                table.insert(node.files, change)
            else
                local existing = find_child_dir(node, segment)
                if not existing then
                    local new = {
                        path = rel,
                        dir = segment,
                        children = {},
                        files = {},
                    }
                    table.insert(node.children, new)
                    node = new
                else
                    node = existing
                end
            end
        end
    end
    return root
end

--- parse the output of git status
--- @param s string
--- @return table<hacked.git.Change>
local parse_git_status = function(s)
    local changes = {}
    for line in s:gmatch("[^\r\n]+") do
        local status = string.sub(line, 1, 2)
        local fp = string.sub(line, 3)
        fp = vim.trim(fp)

        -- handle rename case
        local _, last = fp:find(" -> ")
        if last ~= nil then
            fp = vim.trim(fp:sub(last))
        end

        local segments = vim.split(fp, "/")
        local file = segments[#segments]
        local stage_mark = string.sub(status, 1, 1)
        local unstaged = #vim.trim(string.sub(status, 2, 2)) > 0
        local staged = stage_mark ~= " " and stage_mark ~= "?" and stage_mark ~= "U"
        status = string.sub(vim.trim(status), 1, 1)
        local change = {
            file = file,
            path = fp,
            stage = status == "?" and "untracked"
                or ((unstaged and staged and "partial") or (staged and "staged" or "working")),
            type = (status == "M" or status == "m") and "modified"
                or status == "A" and "added"
                or status == "?" and "added"
                or status == "D" and "deleted"
                or status == "R" and "renamed"
                or "conflict",
        }
        table.insert(changes, change)
    end
    return changes
end

--- @param bufnr integer
--- @param ns integer
--- @param line integer
--- @param name string
--- @param depth integer
local draw_dir = function(bufnr, ns, line, name, depth)
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { " " })
    vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
        virt_text = { { string.rep(" ", depth), "Comment" }, { " " .. name, "MiniIconsBlue" } },
        virt_text_pos = "eol",
    })
end

--- @param bufnr integer
--- @param ns integer
--- @param line integer 0 indexed
--- @param change hacked.git.Change
local draw_file = function(bufnr, ns, line, change)
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { " " })
    local hl = ((change.type == "conflict" and change.stage ~= "staged") or change.type == "deleted") and "MiniIconsRed"
        or (
            change.stage == "partial" and "MiniIconsYellow"
            or (change.stage == "staged" and "MiniIconsGreen" or "MiniIconsGrey")
        )
    local symbol = (change.type == "conflict" and change.stage ~= "staged") and " "
        or (change.stage == "staged" and " " or " ")
    vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
        virt_text = { { string.rep(" ", change.depth), "Comment" }, { symbol .. change.file, hl } },
        virt_text_pos = "eol",
    })
end

--- @param bufnr integer
--- @param tree hacked.git.Dir
--- @param buf_name string current buffer name
local draw_tree = function(bufnr, tree, buf_name)
    local ns = vim.api.nvim_create_namespace("hacked.git.status")
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { " " })
    state.lines_to_path = {}

    if #tree.children == 0 and #tree.files == 0 then
        vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
            virt_text = { { "(clean working tree)", "Comment" } },
            virt_text_pos = "eol",
        })
        return
    end

    local stack = vim.iter(tree.children)
        :map(function(v)
            return vim.tbl_extend("keep", v, { depth = 0 })
        end)
        :totable()
    local line = 0
    while #stack > 0 do
        --- @type hacked.git.Dir
        local node = table.remove(stack, #stack)
        local depth = node.depth or 0
        draw_dir(bufnr, ns, line, node.dir, depth)
        line = line + 1
        for _, change in ipairs(node.files) do
            change.depth = depth + 2
            draw_file(bufnr, ns, line, change)
            line = line + 1
            state.lines_to_path[line] = change

            if change.path == buf_name then
                vim.api.nvim_win_set_cursor(0, { line, 0 })
            end
        end

        -- insert children to top of stack (last one inserted is the first to be written next loop)
        for _, _node in ipairs(node.children) do
            table.insert(stack, vim.tbl_extend("keep", _node, { depth = depth + 1 }))
        end
        -- loop
    end

    for _, change in pairs(tree.files) do
        change.depth = 0
        draw_file(bufnr, ns, line, change)
        line = line + 1
        state.lines_to_path[line] = change

        if change.path == buf_name then
            vim.api.nvim_win_set_cursor(0, { line, 0 })
        end
    end
end

--- resets the change to HEAD
--- @param change hacked.git.Change dir rel path to file to add
H.git_file_reset = function(bufnr, pwinr, winr, change)
    vim.system(
        { "git", "checkout", "HEAD", "--", change.path },
        { text = true },
        vim.schedule_wrap(function(out)
            if #out.stderr > 0 then
                vim.notify("failed to checkout file", vim.log.levels.ERROR, {})
            else
                H.git_status(bufnr, pwinr, winr, "")
            end
        end)
    )
end

--- @param change hacked.git.Change dir rel path to file to add
H.git_toggle = function(bufnr, line, change)
    local cmd = { "git", "add", change.path }
    if change.stage == "staged" then
        cmd = { "git", "restore", "--staged", change.path }
    end

    vim.system(
        cmd,
        { text = true },
        vim.schedule_wrap(function(out)
            if #out.stderr > 0 then
                vim.notify("failed to add file", vim.log.levels.ERROR, {})
            else
                if change.stage == "staged" and change.type == "conflict" then
                    change.stage = "working"
                    change.type = "modified"
                elseif change.stage == "staged" then
                    change.stage = "working"
                else
                    change.stage = "staged"
                end

                local ns = vim.api.nvim_create_namespace("hacked.git.status")
                vim.api.nvim_buf_clear_namespace(bufnr, ns, line - 1, line)
                draw_file(bufnr, ns, line - 1, change)
            end
        end)
    )
end

--- @param bufnr integer
--- @param pwinr integer
--- @param winr integer
--- @param buf_name string
H.git_status = function(bufnr, pwinr, winr, buf_name)
    vim.system(
        { "git", "status", "--short" },
        { text = true },
        vim.schedule_wrap(function(res)
            if #res.stdout > 0 then
                local changes = parse_git_status(res.stdout)
                local tree = tree_rep(changes)

                draw_tree(bufnr, tree, buf_name)

                vim.keymap.set("n", "dd", function()
                    local clnr = vim.fn.getpos(".")[2]
                    local change = state.lines_to_path[clnr]
                    if change then
                        if change.stage == "untracked" then
                            vim.notify("cannot restore untracked file", vim.log.levels.WARN, {})
                            return
                        end

                        confirm.open({
                            prompt = "Are you sure you want to restore " .. change.path .. "?",
                            type = "accept",
                            callback = function(accepted)
                                if accepted then
                                    H.git_file_reset(bufnr, pwinr, winr, change)
                                    vim.notify("restoring " .. change.path, vim.log.levels.INFO, {})
                                else
                                    vim.notify("skipping restore", vim.log.levels.INFO, {})
                                end
                            end,
                        })
                    else
                        vim.notify("not a file", vim.log.levels.ERROR, {})
                    end
                end, { buffer = bufnr })

                vim.keymap.set("n", "<space><space>", function()
                    local clnr = vim.fn.getpos(".")[2]
                    local change = state.lines_to_path[clnr]
                    if change then
                        H.git_toggle(bufnr, clnr, change)
                    else
                        vim.notify("not a file", vim.log.levels.ERROR, {})
                    end
                end, { buffer = bufnr })

                vim.keymap.set("n", "o", function()
                    local clnr = vim.fn.getpos(".")[2]
                    local change = state.lines_to_path[clnr]
                    if change.type == "deleted" then
                        vim.notify("cannot open deleted file", vim.log.levels.WARN, {})
                        return
                    end

                    if change then
                        vim.api.nvim_set_current_win(pwinr)
                        vim.cmd("edit " .. change.path)
                    else
                        vim.notify("not a file", vim.log.levels.ERROR, {})
                    end
                end, { buffer = bufnr })

                vim.keymap.set("n", "<enter>", function()
                    local clnr = vim.fn.getpos(".")[2]
                    local change = state.lines_to_path[clnr]
                    if change.type == "deleted" then
                        vim.notify("cannot open deleted file", vim.log.levels.WARN, {})
                        return
                    end

                    if change then
                        if vim.api.nvim_win_is_valid(winr) then
                            vim.api.nvim_win_close(winr, true)
                        end
                        vim.cmd("edit " .. change.path)
                    else
                        vim.notify("not a file", vim.log.levels.ERROR, {})
                    end
                end, { buffer = bufnr })

                --- allows for any number of custom actions
                for key, action in pairs(config.actions) do
                    vim.keymap.set("n", key, function()
                        local clnr = vim.fn.getpos(".")[2]
                        local change = state.lines_to_path[clnr]
                        if change then
                            change = action(change, { prev_winr = pwinr })
                        end
                    end, { buffer = bufnr })
                end

                vim.keymap.set("n", "q", function()
                    if vim.api.nvim_win_is_valid(winr) then
                        vim.api.nvim_win_close(winr, true)
                    end
                end, { buffer = bufnr })
            else
                -- if there's no diff we close the window?
                vim.notify("No changes found", vim.log.levels.INFO, {})
            end
        end)
    )
end

M.status = function()
    if vim.api.nvim_win_is_valid(state.winr) then
        vim.api.nvim_set_current_win(state.winr)
        return
    end

    local pwinr = vim.api.nvim_get_current_win()
    local relative = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":~:.")
    local editor_width = vim.o.columns
    local width = math.ceil(editor_width * 0.25)

    local float_buf = vim.api.nvim_create_buf(false, true)
    local status_winr = vim.api.nvim_open_win(float_buf, true, {
        win = pwinr,
        width = width,
        split = "left",
        style = "minimal",
    })
    vim.wo[status_winr].winfixwidth = true

    state.winr = status_winr
    H.git_status(float_buf, pwinr, status_winr, relative)
end

return M
