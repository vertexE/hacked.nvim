local M = {}

--- @class hacked.blame.Config

M.setup = function() end

--- @class hacked.blame.Parts
--- @field commit string
--- @field author string
--- @field date string
--- @field time string

--- @param blame string
--- @return hacked.blame.Parts
local parse_blame = function(blame)
	local commit = vim.split(blame, " ", { trimempty = true })[1]
	local author_datetime = vim.split(
		vim.split(blame, "(", { plain = true, trimempty = true })[2],
		")",
		{ plain = true, trimempty = true }
	)[1]
	local _start = string.find(author_datetime, "(%d+%-%d+%-%d+)")
	local author = string.sub(author_datetime, 1, _start - 1)
	local datetime = _start and string.sub(author_datetime, _start) or ""
	local datetime_parts = vim.split(datetime, " ", { trimempty = true })
	local date = #datetime_parts >= 2 and datetime_parts[1] or ""
	local time = #datetime_parts >= 2 and datetime_parts[2] or ""

	commit = string.gsub(commit, "%^", "") --- TODO: there may be more normalization changes I would need to do

	return {
		commit = commit,
		author = vim.trim(author),
		date = date,
		time = time,
	}
end

--- @param commit_sha string
--- @return string
local commit_message = function(commit_sha)
	local cmd = vim.system({ "git", "show", "-s", "--format=%B", commit_sha }, { text = true }):wait()
	if cmd.stdout then
		return vim.trim(cmd.stdout)
	end

	return ""
end

-- vim.print(commit_message("^7c873a0"))

-- vim.print(parse_blame("^7c873a0 (Josiah 2025-01-11 06:45:20 -0500 1) # hacked.nvim"))

--- get the git blame for a line
local blame_win = -1

M.line = function()
	if vim.api.nvim_win_is_valid(blame_win) then
		vim.api.nvim_set_current_win(blame_win)
	end

	-- git blame README.md -L 1,1
	-- the above gets commits
	-- git show -s --format=%B 7c873a0
	-- the above gets commit message
	-- if gh is installed, then we can run on <enter> from float
	-- float should be cursor relative
	-- gh browse 7c873a0

	local rel_path = vim.fn.expand("%:.")
	local cur_pos = vim.fn.getpos(".")[2]
	local blame_bufnr = vim.api.nvim_create_buf(false, true)
	local cmd = vim.system({ "git", "blame", rel_path, string.format("-L %d,%d", cur_pos, cur_pos) }, { text = true })
		:wait()
	vim.print(cmd)
	local blame
	if #cmd.stderr > 0 then
		if string.find(cmd.stderr, "no such path") then
			blame = {
				author = "Untracked File",
				date = "now",
				time = "",
				commit = "00000000",
			}
		end
	elseif #cmd.stdout > 0 then
		blame = parse_blame(cmd.stdout)
	end

	local commit_symbol = ""
	blame_win = vim.api.nvim_open_win(blame_bufnr, false, {
		title = "git blame",
		border = "rounded",
		relative = "cursor",
		-- win = win,
		row = 0,
		col = 2,
		height = 3,
		width = 55,
	})

	vim.keymap.set("n", "<enter>", function()
		vim.system({ "gh", "browse", blame.commit }):wait()
	end, { buffer = blame_bufnr, desc = "git blame: browse commit" })

	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = vim.api.nvim_get_current_buf(),
		callback = function()
			if vim.api.nvim_buf_is_valid(blame_bufnr) then
				vim.api.nvim_buf_delete(blame_bufnr, { force = true })
			end
		end,
	})

	local message = commit_message(blame.commit)
	--- now draw the extmarks...
	local ns_id = vim.api.nvim_create_namespace("hacked.blame.hover")
	vim.api.nvim_buf_set_extmark(blame_bufnr, ns_id, 0, 0, {
		virt_text = {
			{ " ", "TodoFgTODO" },
			{ blame.author .. " ", "TodoFgTODO" },
			{ blame.date .. " " .. blame.time, "Comment" },
		},
		virt_lines = {
			{ { message, "Comment" } },
			{ { commit_symbol .. " " .. blame.commit, "TodoFgTODO" } },
		},
		virt_text_pos = "overlay",
	})
end

--- get the git blame for a selction
M.selection = function() end

--- if github cli is installed,
--- then we will open the current commit
--- sha under the cursor
--- otherwise we attempt to build a url
--- ourselves and then open it
M.browse = function()
    -- TODO: impl 
	-- example path
	-- https://github.com/CopilotC-Nvim/CopilotChat.nvim/commit/59971cd
end

return M
