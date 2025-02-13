local M = {}
local H = {}

--- @alias hacked.git.ChangeType "modified"|"renamed"|"added"|"deleted"|"conflict"
--- @alias hacked.git.Stage "staged"|"untracked"|"working"|"partial"

--- @class hacked.git.State
--- @field lines_to_path table<integer,hacked.git.Change> line number in status buf mapping to file path

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
        local segments = vim.split(fp, "/")
        local file = segments[#segments]
        local stage_mark = string.sub(status, 1, 1)
        local unstaged = #vim.trim(string.sub(status, 2, 2)) > 0
        local staged = stage_mark ~= " " and stage_mark ~= "?"
        status = string.sub(vim.trim(status), 1, 1)
        local change = {
            file = file,
            path = fp,
            stage = (unstaged and staged and "partial") or (staged and "staged" or "working"),
            type = status == "M" and "modified"
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
    vim.print(change)
    local hl = change.type == "conflict" and "MiniIconsRed"
        or (
            change.stage == "partial" and "MiniIconsYellow"
            or (change.stage == "staged" and "MiniIconsGreen" or "MiniIconsGrey")
        )
    vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
        virt_text = { { string.rep(" ", change.depth), "Comment" }, { change.file, hl } },
        virt_text_pos = "eol",
    })
end

--- @param bufnr integer
--- @param tree hacked.git.Dir
local draw_tree = function(bufnr, tree)
    local ns = vim.api.nvim_create_namespace("hacked.git.status")
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    state.lines_to_path = {}

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
    end
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
                change.stage = change.stage == "staged" and "working" or "staged"
                local ns = vim.api.nvim_create_namespace("hacked.git.status")
                vim.api.nvim_buf_clear_namespace(bufnr, ns, line - 1, line)
                draw_file(bufnr, ns, line - 1, change)
            end
        end)
    )
end

--- @param bufnr integer
--- @param winr integer
H.git_status = function(bufnr, winr)
    vim.system(
        { "git", "status", "--short" },
        { text = true },
        vim.schedule_wrap(function(res)
            if #res.stdout > 0 then
                local changes = parse_git_status(res.stdout)
                local tree = tree_rep(changes)

                draw_tree(bufnr, tree)

                vim.keymap.set("n", "<space>", function()
                    local clnr = vim.fn.getpos(".")[2]
                    local change = state.lines_to_path[clnr]
                    if change then
                        H.git_toggle(bufnr, clnr, change)
                    else
                        vim.notify("not a file", vim.log.levels.ERROR, {})
                    end
                end)

                vim.keymap.set("n", "<enter>", function()
                    local clnr = vim.fn.getpos(".")[2]
                    local change = state.lines_to_path[clnr]
                    if change then
                        if vim.api.nvim_win_is_valid(winr) then
                            vim.api.nvim_win_close(winr, true)
                        end
                        vim.cmd("edit " .. change.path)
                    else
                        vim.notify("not a file", vim.log.levels.ERROR, {})
                    end
                end)

                vim.keymap.set("n", "q", function()
                    if vim.api.nvim_win_is_valid(winr) then
                        vim.api.nvim_win_close(winr, true)
                    end
                end)
            end
        end)
    )
end

M.status = function()
    local editor_width = vim.o.columns
    local editor_height = vim.o.lines
    local width = math.ceil(editor_width * 0.5)
    local height = math.ceil(editor_height * 0.8)
    local row = (editor_height - height) / 2
    local col = (editor_width - width) / 2

    local float_buf = vim.api.nvim_create_buf(false, true)
    local winr = vim.api.nvim_open_win(float_buf, true, {
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
    })
    H.git_status(float_buf, winr)
end

return M
