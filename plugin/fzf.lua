vim.api.nvim_create_user_command("Fzf", function(input)
	local arg = input.fargs[1]
	if arg == "files" then
		require("fzf").files()
	elseif arg == "live_grep" then
		require("fzf").live_grep()
	elseif arg == "buffers" then
		require("fzf").buffers()
	elseif arg == "help_tags" then
		require("fzf").help_tags()
	end
end, {
	nargs = 1,
	complete = function(_, line, col)
		local prefix_from, prefix_to, prefix = string.find(line, "^%S+%s+(%S*)")
		if col < prefix_from or prefix_to < col then
			return {}
		end
		local candidates = vim.tbl_filter(function(x)
			return tostring(x):find(prefix, 1, true) ~= nil
		end, { "files", "live_grep", "buffers", "help_tags" })
		return candidates
	end,
})
