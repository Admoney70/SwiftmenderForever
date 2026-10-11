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
	print("  /sm offset <x> <y>     - marker offset in pixels from its anchor")
	print("  /sm marker | border    - toggle the marker icon / raid-frame border")
	print("  /sm spiral | timer     - toggle the marker's HoT spiral / countdown")
	print("  /sm bordersize <1-10>  - raid-frame border thickness")
	print("  /sm markerborder [1-10] - toggle the marker icon border, or set its thickness")
	print("  /sm markerfade [0-1]   - toggle fading markers on Swiftmend cooldown, or set the opacity")
	print("  /sm overheal [amount|auto] - toggle 'only show when it won't overheal', or set the heal amount")
	print("  /sm iconborder [1-10]  - toggle the target icon border, or set its thickness")
	print("  /sm icontimer          - toggle the HoT time-left number on the target icon")
	print("  /sm pattern add|remove|list <blizzard|buzzard> <lua pattern>")
	print("  /sm frames             - list unit frames that aren't hooked yet")
	print("  /sm scan               - rescan for raid frames")
	print("  /sm legacy             - toggle the old out-of-combat-only tracking (reloads)")
	print("  /sm status | reset")
end

local function Status()
	local c = ns.Frames:Count()
	ns.Print(string.format("icon %s (%s, cooldown fade %.2f), only mine %s",
		OnOff(ns.db.icon.enabled), ns.db.icon.locked and "locked" or "unlocked",
		ns.db.icon.cooldownAlpha, OnOff(ns.db.onlyMine)))
	ns.Print(string.format("Blizzard frames %s (%d hooked), Buzzard frames %s (%d hooked)",
		OnOff(ns.db.overlay.blizzard), c.blizzard or 0, OnOff(ns.db.overlay.buzzard), c.buzzard or 0))
	ns.Print("knows Swiftmend: " .. OnOff(ns.KnowsSwiftmend())
		.. ", combat tracking: " .. (ns.Native.Available() and "native" or "unavailable (out-of-combat only)"))
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
		ns.Native.RefreshFilters()
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
	elseif cmd == "offset" then
		local x, y = rest:match("^(%-?[%d%.]+)%s+(%-?[%d%.]+)$")
		if not x then
			ns.Print("usage: /sm offset <x> <y>   (now " .. db.overlay.offsetX .. " " .. db.overlay.offsetY .. ")")
			return
		end
		db.overlay.offsetX, db.overlay.offsetY = tonumber(x), tonumber(y)
		ns.Frames:Relayout()
		ns.Print("marker offset " .. db.overlay.offsetX .. ", " .. db.overlay.offsetY)
	elseif cmd == "marker" then
		db.overlay.showIcon = not db.overlay.showIcon
		ns.Frames:Relayout()
		ns.Print("frame marker icon " .. OnOff(db.overlay.showIcon))
	elseif cmd == "spiral" or cmd == "timer" then
		local key = cmd == "spiral" and "showSpiral" or "showTimer"
		db.overlay[key] = not db.overlay[key]
		ns.Frames:Relayout()
		ns.Print("frame marker " .. cmd .. " " .. OnOff(db.overlay[key]))
	elseif cmd == "bordersize" and tonumber(rest) then
		db.overlay.borderSize = math.max(1, math.min(10, math.floor(tonumber(rest))))
		ns.Frames:Relayout()
		ns.Print("frame border thickness " .. db.overlay.borderSize)
	elseif cmd == "overheal" then
		if rest == "auto" then
			db.overlay.overhealAmount, db.overlay.noOverheal = 0, true
		elseif tonumber(rest) then
			db.overlay.overhealAmount, db.overlay.noOverheal = math.max(0, math.floor(tonumber(rest))), true
		else
			db.overlay.noOverheal = not db.overlay.noOverheal
		end
		ns.Overheal.UpdateEstimate()
		ns.Frames:Refresh()
		local heal = ns.Overheal.HealAmount()
		ns.Print("only show markers when it won't overheal: " .. OnOff(db.overlay.noOverheal)
			.. " (heal " .. (heal and tostring(heal) or "unknown") .. ")")
	elseif cmd == "markerfade" then
		if tonumber(rest) then
			db.overlay.cooldownAlpha = math.max(0, math.min(1, tonumber(rest)))
			db.overlay.fadeOnCooldown = true
		else
			db.overlay.fadeOnCooldown = not db.overlay.fadeOnCooldown
		end
		ns.Frames:Refresh()
		ns.Print(string.format("fade markers on cooldown %s (%.2f)", OnOff(db.overlay.fadeOnCooldown), db.overlay.cooldownAlpha))
	elseif cmd == "markerborder" then
		if tonumber(rest) then
			db.overlay.iconBorderSize = math.max(1, math.min(10, math.floor(tonumber(rest))))
			db.overlay.showIconBorder = true
		else
			db.overlay.showIconBorder = not db.overlay.showIconBorder
		end
		ns.Frames:Relayout()
		ns.Print("marker icon border " .. OnOff(db.overlay.showIconBorder) .. " (" .. db.overlay.iconBorderSize .. "px)")
	elseif cmd == "icontimer" then
		db.icon.showTimer = not db.icon.showTimer
		ns.Icon:Layout()
		ns.Print("target icon HoT timer " .. OnOff(db.icon.showTimer))
	elseif cmd == "iconborder" then
		if tonumber(rest) then
			db.icon.borderSize = math.max(1, math.min(10, math.floor(tonumber(rest))))
			db.icon.showBorder = true
		else
			db.icon.showBorder = not db.icon.showBorder
		end
		ns.Icon:Layout()
		ns.Print("icon border " .. OnOff(db.icon.showBorder) .. " (" .. db.icon.borderSize .. "px)")
	elseif cmd == "border" then
		db.overlay.showBorder = not db.overlay.showBorder
		ns.Frames:Relayout()
		ns.Print("raid frame border " .. OnOff(db.overlay.showBorder))
	elseif cmd == "pattern" then
		Pattern(rest)
	elseif cmd == "frames" then
		ns.Print("unit frames without a Swiftmender marker:")
		ns.Frames:ListUnmatched()
	elseif cmd == "scan" then
		ns.Frames:ScanNow()
		ns.RefreshAll()
		Status()
	elseif cmd == "legacy" then
		db.forceLegacy = not db.forceLegacy
		ReloadUI()
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
