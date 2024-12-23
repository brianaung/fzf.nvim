local M = {}

--- Execute fuzzy operation in a terminal session.
---@param name string
---@param cmd string
---@param on_choice function
function M.fuzzy(name, cmd, on_choice)
	-- Opens an ivy-mode like floating window.
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].bufhidden = "wipe"
	local height = math.floor(vim.o.lines * 0.3)
	local winid = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = vim.o.columns,
		height = height,
		row = vim.o.lines - height,
		col = 0,
		title = { { " " .. name .. " ", "None" } },
		border = { "─", "─", "─", " ", " ", " ", " ", " " },
		style = "minimal",
	})

	vim.api.nvim_create_autocmd({ "TermOpen" }, {
		command = "startinsert",
		once = true,
	})
	vim.api.nvim_create_autocmd("TermClose", {
		callback = function()
			pcall(vim.api.nvim_win_close, winid, false)
		end,
		once = true,
	})

	local tmpfile = vim.fn.tempname()
	vim.api.nvim_buf_call(bufnr, function()
		vim.fn.termopen({
			vim.o.shell,
			vim.o.shellcmdflag,
			string.format('%s > "%s"', cmd, tmpfile),
		}, {
			on_exit = function()
				local f = io.open(tmpfile)
				if not f then
					return
				end
				local choices = vim.split(f:read "*a", "\n", { trimempty = true })
				if next(choices) then
					on_choice(choices)
				end
				f:close()
				-- TODO os.remove(tmpfile)
			end,
		})
	end)
end

--- Find files in cwd.
---@return nil
function M.files()
	M.fuzzy("Files", "fd --type=file | fzf --reverse --multi --bind='ctrl-q:select-all+accept'", function(choices)
		if #choices > 1 then
			M._setqflist(choices)
		else
			vim.cmd.edit(choices[1])
		end
	end)
end

--- Live grep file contents.
---@return nil
function M.live_grep()
	local function parser(s)
		s = string.match(s, ".+:%d+:.+")
		-- TOOD incorrect parsing of parts[4] and beyond
		local parts = s and vim.split(s, ":") or {}
		return {
			filename = parts[1],
			lnum = parts[2],
			col = parts[3],
			text = parts[4],
		}
	end

	M.fuzzy(
		"Live grep",
		"rg --column --color=always '' | fzf --ansi --reverse --multi --bind='ctrl-q:select-all+accept'",
		function(choices)
			if #choices > 1 then
				M._setqflist(choices, parser)
			else
				local parsed = parser(choices[1])
				vim.cmd("edit +" .. parsed.lnum .. " " .. parsed.filename)
			end
		end
	)
end

--- Find active buffer files.
---@return nil
function M.buffers()
	local buffers = vim.fn.getbufinfo { buflisted = 1 }
	table.sort(buffers, function(a, b)
		return a.lastused > b.lastused
	end)

	local tmpfile = M._write_file(vim.iter(ipairs(buffers))
		:map(function(_, b)
			local hidden = b.hidden == 1 and "h" or "a"
			local readonly = vim.api.nvim_buf_get_option(b.bufnr, "readonly") and "=" or " "
			local changed = b.changed == 1 and "+" or " "
			local flag = b.bufnr == vim.fn.bufnr "" and "%" or (b.bufnr == vim.fn.bufnr "#" and "#" or " ")
			local indicator = flag .. hidden .. readonly .. changed
			return string.format("[%s] %s %s:%s", b.bufnr, indicator, vim.fn.bufname(b.bufnr), b.lnum)
		end)
		:totable())

	M.fuzzy(
		"Buffers",
		string.format("cat %s | fzf --reverse --multi --bind='ctrl-q:select-all+accept'", tmpfile),
		function(choices)
			if #choices > 1 then
				M._setqflist(choices, function(c)
					local _, buf = vim.iter(ipairs(buffers)):find(function(_, b)
						return b.bufnr == tonumber(c:match "^%[(%d+)%]")
					end)
					return buf and {
						bufnr = buf.bufnr,
						lnum = buf.lnum,
						col = 1,
					} or {}
				end)
			else
				vim.cmd.buffer(choices[1]:match "^%[(%d+)%]")
			end
			-- TODO os.remove(tmpfile)
		end
	)
end

--- Find neovim help tags.
---@return nil
function M.help_tags()
	local help_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[help_buf].buftype = "help"
	local tags = vim.api.nvim_buf_call(help_buf, function()
		return vim.fn.taglist ".*"
	end)
	vim.api.nvim_buf_delete(help_buf, { force = true })

	local tmpfile = M._write_file(vim.iter(ipairs(tags))
		:map(function(_, t)
			return t.name
		end)
		:totable())

	M.fuzzy(
		"Help tags",
		string.format("cat %s | fzf --reverse --multi --bind='ctrl-q:select-all+accept'", tmpfile),
		function(choices)
			if #choices > 1 then
				M._setqflist(choices)
			else
				vim.cmd.help(choices[1])
			end
			-- TODO os.remove(tmpfile)
		end
	)
end

function M._setqflist(choices, parser)
	parser = parser and parser
		or function(c)
			return {
				filename = c,
				lnum = 1,
				col = 1,
				text = "",
			}
		end
	local qflist = vim.iter(ipairs(choices))
		:map(function(_, c)
			return parser(c)
		end)
		:totable()
	vim.fn.setqflist(qflist, "r")
	vim.cmd.copen()
end

function M._write_file(content)
	local tmpfile = vim.fn.tempname()
	local f = io.open(tmpfile, "w")
	if f then
		for _, c in ipairs(content) do
			f:write(c .. "\n")
		end
		f:close()
	end
	return tmpfile
end

return M
