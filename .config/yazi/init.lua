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
