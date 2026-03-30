-- luacheck: globals Status
-- Show symlink target in status bar
Status:children_add(function(self)
	local h = self._current.hovered
	if h and h.link_to then
		return " -> " .. tostring(h.link_to)
	else
		return ""
	end
end, 3300, Status.LEFT)

-- Show owner:group in status bar
Status:children_add(function(self)
	local h = self._current.hovered
	if not h or not h.cha then
		return ""
	end

	return string.format(" %s:%s ", h.cha.uid or "", h.cha.gid or "")
end, 500, Status.RIGHT)

-- Git integration
require("git"):setup()

-- Full border with rounded corners
-- luacheck: globals ui
require("full-border"):setup { type = ui.Border.ROUNDED }

-- macOS Finder tags (Catppuccin Mocha colors)
require("mactag"):setup {
	keys = {
		r = "Red", o = "Orange", y = "Yellow",
		g = "Green", b = "Blue", p = "Purple",
	},
	colors = {
		Red = "#f38ba8", Orange = "#fab387", Yellow = "#f9e2af",
		Green = "#a6e3a1", Blue = "#89b4fa", Purple = "#cba6f7",
	},
	order = 500,
}
