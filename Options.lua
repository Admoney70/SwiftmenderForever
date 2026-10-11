-- Swiftmender Forever: slash commands. /sm on its own opens the settings
-- window; the subcommands below are shortcuts.

local ADDON, ns = ...

local function OnOff(v) return v and "|cff33ff33on|r" or "|cffff3333off|r" end

local POINTS = {
	TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
	RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local function Help()
	ns.Print("/sm opens the settings window. Shortcuts:")
	print("  /sm lock | unlock      - lock or move the target icon")
	print("  /sm icon               - toggle the target icon")
	print("  /sm iconsize <n>       - target icon size (default 48)")
	print("  /sm fade <0-1>         - icon alpha while Swiftmend is on cooldown")
	print("  /sm mine               - only count your own Rejuv/Regrowth")
	print("  /sm blizzard | buzzard - toggle overlays on those raid frames")
	print("  /sm size <n>           - raid-frame marker size (default 14)")
	print("  /sm anchor <point> [x y] - marker position, e.g. TOPRIGHT -2 -2")
	print("  /sm marker | border    - toggle the marker icon / green border")
	print("  /sm pattern add|remove|list <blizzard|buzzard> <lua pattern>")
	print("  /sm frames             - list unit frames that aren't hooked yet")
	print("  /sm scan               - rescan for raid frames")
	print("  /sm status | reset")
end

local function Status()
	local c = ns.Frames:Count()
	ns.Print(string.format("icon %s (%s, cooldown fade %.2f), only mine %s",
		OnOff(ns.db.icon.enabled), ns.db.icon.locked and "locked" or "unlocked",
		ns.db.icon.cooldownAlpha, OnOff(ns.db.onlyMine)))
	ns.Print(string.format("Blizzard frames %s (%d hooked), Buzzard frames %s (%d hooked)",
		OnOff(ns.db.overlay.blizzard), c.blizzard or 0, OnOff(ns.db.overlay.buzzard), c.buzzard or 0))
	ns.Print("knows Swiftmend: " .. OnOff(ns.KnowsSwiftmend()))
end

local function Pattern(args)
	local action, provider, pat = args:match("^(%S+)%s*(%S*)%s*(.-)%s*$")
	local list = ns.db.overlay.patterns
	if action == "list" or not action then
		for _, p in ipairs({ "blizzard", "buzzard" }) do
			ns.Print(p .. ": " .. table.concat(list[p] or {}, "  "))
		end
		return
	end
	if not list[provider] or pat == "" then
		ns.Print("usage: /sm pattern add|remove blizzard|buzzard <lua pattern>")
		return
	end
	if action == "add" then
		if not pcall(string.match, "", pat) then
			ns.Print("invalid Lua pattern: " .. pat)
			return
		end
		table.insert(list[provider], pat)
		ns.Print("added " .. pat .. " to " .. provider)
		ns.Frames:Scan()
	elseif action == "remove" then
		for i, p in ipairs(list[provider]) do
			if p == pat then
				table.remove(list[provider], i)
				ns.Print("removed " .. pat .. " (reload to drop existing markers)")
				return
			end
		end
		ns.Print(pat .. " not found")
	end
end

local function Handler(msg)
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	local db = ns.db

	if cmd == "lock" or cmd == "unlock" then
		db.icon.locked = (cmd == "lock")
		ns.Icon:Layout()
		ns.Print("icon " .. (db.icon.locked and "locked" or "unlocked - drag it, right-click to lock"))
	elseif cmd == "icon" then
		db.icon.enabled = not db.icon.enabled
		ns.Icon:Layout()
		ns.Print("icon " .. OnOff(db.icon.enabled))
	elseif cmd == "iconsize" and tonumber(rest) then
		db.icon.size = math.max(16, math.min(200, tonumber(rest)))
		ns.Icon:Layout()
	elseif cmd == "fade" and tonumber(rest) then
		db.icon.cooldownAlpha = math.max(0, math.min(1, tonumber(rest)))
		ns.RefreshAll()
		ns.Print(string.format("icon alpha on cooldown: %.2f", db.icon.cooldownAlpha))
	elseif cmd == "mine" then
		db.onlyMine = not db.onlyMine
		ns.RefreshAll()
		ns.Print("only my HoTs " .. OnOff(db.onlyMine))
	elseif cmd == "blizzard" or cmd == "buzzard" then
		db.overlay[cmd] = not db.overlay[cmd]
		ns.RefreshAll()
		ns.Print(cmd .. " raid frames " .. OnOff(db.overlay[cmd]))
	elseif cmd == "size" and tonumber(rest) then
		db.overlay.size = math.max(6, math.min(64, tonumber(rest)))
		ns.Frames:Relayout()
	elseif cmd == "anchor" then
		local point, x, y = rest:upper():match("^(%S+)%s*(%-?[%d%.]*)%s*(%-?[%d%.]*)")
		if not point or not POINTS[point] then
			ns.Print("points: TOPLEFT TOP TOPRIGHT LEFT CENTER RIGHT BOTTOMLEFT BOTTOM BOTTOMRIGHT")
			return
		end
		db.overlay.point = point
		db.overlay.offsetX = tonumber(x) or 0
		db.overlay.offsetY = tonumber(y) or 0
		ns.Frames:Relayout()
	elseif cmd == "marker" then
		db.overlay.showIcon = not db.overlay.showIcon
		ns.Frames:Relayout()
		ns.Print("frame marker icon " .. OnOff(db.overlay.showIcon))
	elseif cmd == "border" then
		db.overlay.showBorder = not db.overlay.showBorder
		ns.Frames:Relayout()
		ns.Print("frame border " .. OnOff(db.overlay.showBorder))
	elseif cmd == "pattern" then
		Pattern(rest)
	elseif cmd == "frames" then
		ns.Print("unit frames without a Swiftmender marker:")
		ns.Frames:ListUnmatched()
	elseif cmd == "scan" then
		ns.Frames:ScanNow()
		ns.RefreshAll()
		Status()
	elseif cmd == "status" then
		Status()
	elseif cmd == "reset" then
		ns.ResetDB()
		ns.Icon:Layout()
		ns.Frames:Relayout()
		ns.Print("settings reset")
	elseif cmd == "" or cmd == "config" or cmd == "options" then
		ns.Config:Toggle()
	else
		Help()
	end
end

SLASH_SWIFTMENDERFOREVER1 = "/swiftmender"
SLASH_SWIFTMENDERFOREVER2 = "/sm"
SlashCmdList.SWIFTMENDERFOREVER = Handler
