-- Swiftmender Forever: draggable target icon.
-- Shows greyed out, and lights up when your target (including yourself)
-- can be Swiftmended; with no friendly target it follows you instead,
-- showing their name and the HoT time left. Behaves like an action button:
-- a cooldown spiral (and fade) while Swiftmend is on cooldown, a red tint
-- when the target is out of range, blue when you lack the mana, and
-- desaturated when Swiftmend can't be used. Optionally glows while the
-- target is missing enough health that Swiftmend won't overheal.
--
-- In combat the lit icon comes from native aura sensors on "target" (and a
-- second set on "player", swapped in when there's no friendly target)
-- (Native.lua). Those buttons can't be restyled while auras are secret, so
-- there is one sensor per look (normal / range / mana / unusable), each
-- styled once, and we switch looks by showing only that sensor's parent
-- frame -- our own frames stay writable in combat. The overheal glow is a
-- fifth sensor that only draws a glow, under a frame of ours whose alpha is
-- the overheal curve (Overheal.FitsAlpha), which accepts secret health.

local ADDON, ns = ...
local IsSecret = ns.IsSecret

local Icon = {}
ns.Icon = Icon

local button
local STATES = { "normal", "range", "mana", "unusable" }
local TINTS = {
	normal = { 1, 1, 1 },
	range = { 1, 0.25, 0.25 },
	mana = { 0.35, 0.5, 1 },
	unusable = { 0.75, 0.75, 0.75 },
}

local function SavePosition()
	local point, _, relPoint, x, y = button:GetPoint(1)
	ns.db.icon.point = { point, "UIParent", relPoint, x, y }
end

local function ApplyPosition()
	local p = ns.db.icon.point
	button:ClearAllPoints()
	button:SetPoint(p[1] or "CENTER", UIParent, p[3] or "CENTER", p[4] or 0, p[5] or 0)
end

local function LabelOffset(cfg)
	return -2 - (cfg.showBorder and cfg.borderSize or 0)
end

local function ApplyLook(tex, state)
	local tint = TINTS[state] or TINTS.normal
	tex:SetDesaturated(state == "unusable")
	tex:SetVertexColor(tint[1], tint[2], tint[3])
end

--------------------------------------------------------------------------
-- Swiftmend state (range / mana / usable / cooldown)
--------------------------------------------------------------------------

-- Spell to query: the exact id from the spellbook when known (Forever may
-- use its own ids), otherwise the base id.
local function SwiftmendSpell()
	local name = ns.SpellName(ns.SPELLS.SWIFTMEND)
	local info = name and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
	local id = info and not IsSecret(info) and info.spellID
	if type(id) == "number" and not IsSecret(id) then return id end
	return ns.SPELLS.SWIFTMEND
end

local function Usability(spell)
	local usable, noMana
	if C_Spell and C_Spell.IsSpellUsable then
		usable, noMana = C_Spell.IsSpellUsable(spell)
	elseif IsUsableSpell then
		usable, noMana = IsUsableSpell(spell)
	else
		return true, false
	end
	if IsSecret(usable) then usable = true end
	if IsSecret(noMana) then noMana = false end
	return usable and true or false, noMana and true or false
end

-- nil when unknown (no target, secret, or no range data)
local function InRange(spell, unit)
	if unit == "player" then return true end
	local r
	if C_Spell and C_Spell.IsSpellInRange then
		r = C_Spell.IsSpellInRange(spell, unit)
	elseif IsSpellInRange then
		r = IsSpellInRange(ns.SpellName(spell) or "Swiftmend", unit)
		if r == 1 then r = true elseif r == 0 then r = false end
	end
	if IsSecret(r) then return nil end
	return r
end

-- True while Swiftmend is on its own cooldown (the global cooldown alone
-- doesn't count).
local function OnCooldown(spell)
	local info = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spell)
	if IsSecret(info) then info = nil end
	if info then
		local start, duration, gcd = info.startTime, info.duration, info.isOnGCD
		if not IsSecret(start) and not IsSecret(duration) and start and duration then
			return duration > 1.5 and start + duration - GetTime() > 0
		end
		local active = info.isActive
		if not IsSecret(active) and active ~= nil then
			return active and not (not IsSecret(gcd) and gcd) or false
		end
	elseif GetSpellCooldown then
		local start, duration = GetSpellCooldown(spell)
		if start and duration then
			return duration > 1.5 and start + duration - GetTime() > 0
		end
	end
	-- cooldown values are secret: fall back to whether the swipe is running
	return button.cooldown:IsShown() and true or false
end

-- Which look the icon should have right now.
local function CurrentState(cfg, spell, unit)
	local usable, noMana = Usability(spell)
	if noMana and cfg.tintMana then return "mana" end
	if not usable and cfg.desatUnusable then return "unusable" end
	if cfg.tintRange and InRange(spell, unit) == false then return "range" end
	return "normal"
end

--------------------------------------------------------------------------
-- native sensors
--------------------------------------------------------------------------

-- Styles one native slot button (see Native.lua for the rules). Runs each
-- time Blizzard creates the button, so it is also how settings and the
-- unit's name reach it.
local function DecorateTarget(b, set, state)
	set.natives[state] = b
	if b.SetMouseClickEnabled then b:SetMouseClickEnabled(false) end
	if b.SetMouseMotionEnabled then b:SetMouseMotionEnabled(false) end
	b:ClearAllPoints()
	b:SetAllPoints(button)
	if not b.smIcon then
		b.smIcon = b:CreateTexture(nil, "ARTWORK")
		b.smIcon:SetAllPoints(b)
		b.smIcon:SetTexture(ns.SpellTexture(ns.SPELLS.SWIFTMEND))
		b.smIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local host = CreateFrame("Frame", nil, b)
		host:SetAllPoints(b)
		host:SetFrameLevel(b:GetFrameLevel() + 3)
		b.smTimer = host:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		b.smTimer:SetPoint("TOPLEFT", 3, -3)
		b.smLabel = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		b.smEdges = ns.CreateEdges(host)
	end
	ApplyLook(b.smIcon, state)
	local cfg = ns.db.icon
	ns.LayoutEdges(b.smEdges, b, cfg.borderSize, cfg.borderColor, cfg.showBorder, true)
	b.smLabel:SetPoint("TOP", b, "BOTTOM", 0, LabelOffset(cfg))
	if cfg.showTimer then
		b.smTimer:Show()
		b:SetDurationText(b.smTimer, ns.Native.TimerOptions())
	else
		b:ClearDurationText()
		b.smTimer:Hide()
	end
	-- the button is recreated for each new aura, so this follows target swaps
	b.smLabel:SetText(UnitName(set.unit))
end

-- The glow sensor's button: no icon, just the glow, shown while the unit
-- has the HoT.
local function DecorateGlow(b, set)
	set.glowNative = b
	if b.SetMouseClickEnabled then b:SetMouseClickEnabled(false) end
	if b.SetMouseMotionEnabled then b:SetMouseMotionEnabled(false) end
	b:ClearAllPoints()
	b:SetAllPoints(button)
	if b.ClearDurationText then b:ClearDurationText() end
	if not b.smGlow then b.smGlow = ns.Glow.Create(b, button) end
	ns.Glow.Apply(b.smGlow, ns.db.icon)
end

-- One full set of sensors (a proxy per look, plus the glow) for one unit,
-- under a root frame of ours so the whole set can be swapped in combat.
local function CreateSet(unit)
	local set = { unit = unit, proxies = {}, sensors = {}, natives = {} }
	set.root = CreateFrame("Frame", nil, button)
	set.root:SetAllPoints(button)
	for i, state in ipairs(STATES) do
		local proxy = CreateFrame("Frame", nil, set.root)
		proxy:SetAllPoints(button)
		proxy:SetFrameLevel(button:GetFrameLevel() + i)
		local sensor = ns.Native.CreateSensor(proxy, unit, function(b) DecorateTarget(b, set, state) end)
		if not sensor then return end
		proxy:SetShown(state == "normal")
		set.proxies[state], set.sensors[state] = proxy, sensor
	end
	-- overheal gate -> glow sensor (the margin leaves room for the glow)
	set.glowGate = ns.Overheal.CreateGate(set.root, 200)
	set.glowGate.clip:SetFrameLevel(button:GetFrameLevel() + 10)
	set.glowSensor = ns.Native.CreateSensor(set.glowGate.clip, unit, function(b) DecorateGlow(b, set) end)
	set.state = "normal"
	return set
end

local function CreateSensors()
	local target, player = CreateSet("target"), CreateSet("player")
	if not (target and player) then return false end
	button.sets = { target = target, player = player }
	button.sensors = true
	player.root:Hide()
	button.active = "target"
	return true
end

local function ShowSet(unit)
	if button.active == unit then return end
	button.active = unit
	for u, set in pairs(button.sets) do set.root:SetShown(u == unit) end
end

local function ShowState(set, state)
	if set.state == state then return end
	set.state = state
	for s, proxy in pairs(set.proxies) do proxy:SetShown(s == state) end
end

--------------------------------------------------------------------------
-- frame
--------------------------------------------------------------------------

local function Create()
	-- Display only (not a secure button), so it can be shown, hidden and
	-- moved freely during combat.
	button = CreateFrame("Frame", "SwiftmenderForeverIcon", UIParent)
	button:SetClampedToScreen(true)
	button:SetMovable(true)
	button:RegisterForDrag("LeftButton")
	button:SetFrameStrata("MEDIUM")

	button.tex = button:CreateTexture(nil, "ARTWORK")
	button.tex:SetAllPoints()
	button.tex:SetTexture(ns.SpellTexture(ns.SPELLS.SWIFTMEND))
	button.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- overheal glow for the out-of-combat fallback (native mode uses a sensor)
	button.glowHost = CreateFrame("Frame", nil, button)
	button.glowHost:SetAllPoints()
	button.glowHost:SetFrameLevel(button:GetFrameLevel() + 10)
	button.glow = ns.Glow.Create(button.glowHost, button)
	button.glowHost:Hide()

	-- Swiftmend cooldown spiral, above the native sensors
	button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	button.cooldown:SetAllPoints()
	button.cooldown:SetDrawEdge(false)
	button.cooldown:SetFrameLevel(button:GetFrameLevel() + 20)

	local text = CreateFrame("Frame", nil, button)
	text:SetAllPoints()
	text:SetFrameLevel(button:GetFrameLevel() + 22)

	button.timer = text:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	button.timer:SetPoint("TOPLEFT", 3, -3)

	button.label = text:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	button.label:SetPoint("TOP", button, "BOTTOM", 0, -2)
	button.edges = ns.CreateEdges(text)

	button.hint = text:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.hint:SetPoint("BOTTOM", button, "TOP", 0, 2)
	button.hint:SetText("Swiftmender\n|cffaaaaaadrag me, /sm lock|r")

	button:SetScript("OnDragStart", function(self)
		if not ns.db.icon.locked then self:StartMoving() end
	end)
	button:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	button:SetScript("OnMouseUp", function(_, mouse)
		if mouse == "RightButton" and not ns.db.icon.locked then
			ns.db.icon.locked = true
			ns.Print("icon locked (/sm unlock to move it again)")
			Icon:Layout()
		end
	end)
	button:SetScript("OnEnter", function(self)
		if ns.db.icon.locked then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Swiftmender Forever")
		GameTooltip:AddLine("Left-drag to move, right-click to lock.", 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)

	if ns.Native.Available() and not CreateSensors() then
		button.sensors = nil
	end
end

local pendingStyle
-- Restyle native buttons (border, label offset); deferred while secret.
local function StyleNatives()
	if not ns.Native.Mutable() then
		pendingStyle = true
		return
	end
	pendingStyle = nil
	for _, set in pairs(button.sets) do
		for state, b in pairs(set.natives) do DecorateTarget(b, set, state) end
		if set.glowNative then DecorateGlow(set.glowNative, set) end
	end
end

function Icon:Layout()
	if not button then return end
	local cfg = ns.db.icon
	button:SetSize(cfg.size, cfg.size)
	ns.Glow.Apply(button.glow, cfg)
	if button.sensors then
		StyleNatives()
		-- shown/hidden with the greyed base in Refresh
		ns.LayoutEdges(button.edges, button, cfg.borderSize, cfg.borderColor, false, true)
	else
		ns.LayoutEdges(button.edges, button, cfg.borderSize, cfg.borderColor, cfg.showBorder, true)
	end
	button.label:SetPoint("TOP", button, "BOTTOM", 0, LabelOffset(cfg))
	button:EnableMouse(not cfg.locked)
	button.hint:SetShown(not cfg.locked)
	ApplyPosition()
	self:Refresh()
end

-- Whether the target can be helped: true, false, or nil when that's secret.
local function TargetHelpable()
	local exists = UnitExists("target")
	if IsSecret(exists) then return nil end
	if not exists then return false end
	local ok = UnitCanAssist and UnitCanAssist("player", "target")
	if ok == nil or IsSecret(ok) then ok = UnitIsFriend("player", "target") end
	if IsSecret(ok) then return nil end
	return ok and true or false
end

local function FriendlyTarget()
	return TargetHelpable() == true
end

-- The unit the icon follows: your target when it's friendly (yourself
-- included), otherwise yourself when that option is on. When friendliness
-- is unreadable it stays on the target.
local function TrackedUnit()
	if ns.db.icon.trackSelf and TargetHelpable() == false then return "player" end
	return "target"
end
Icon.TrackedUnit = TrackedUnit

function Icon:Refresh()
	if not button then return end
	local cfg = ns.db.icon

	if not cfg.enabled or (cfg.onlyWhenKnown and not ns.KnowsSwiftmend() and cfg.locked) then
		button:Hide()
		return
	end
	button:Show()

	local unit = TrackedUnit()
	local spell = SwiftmendSpell()
	local onCD = OnCooldown(spell)
	local state = CurrentState(cfg, spell, unit)
	local spiral = onCD and cfg.showCooldown
	local helpable = unit == "player" or FriendlyTarget()

	if button.sensors then
		ShowSet(unit)
		local set = button.sets[unit]
		ShowState(set, state)
		-- The greyed base icon is ours and always drawn; the native button
		-- covers it with the lit icon only while the target has the HoT, so
		-- this needs no aura data and works in combat.
		local showBase = cfg.showInactive or not cfg.locked
		-- Without the base, out of combat we know whether the icon is lit; in
		-- combat we don't, so the spiral then sits on a faint ghost icon.
		local known = ns.Native.Mutable()
		local lit = known and helpable and ns.Evaluate(unit)
		local showSpiral = spiral and (showBase or lit or not known)
		button.cooldown:SetAlpha(showSpiral and 1 or 0)
		ApplyLook(button.tex, "unusable")
		if showBase then
			button.tex:Show()
			button.tex:SetAlpha(cfg.locked and 1 or 0.6)
		elseif showSpiral and not lit then
			button.tex:Show()
			button.tex:SetAlpha(0.35)
		else
			button.tex:Hide()
		end
		-- the greyed base keeps the border too (the lit native button draws
		-- the same border on top of it)
		local edgesShown = cfg.showBorder and showBase and true or false
		for i = 1, 4 do button.edges[i]:SetShown(edgesShown) end
		button.label:SetText("")
		button.timer:SetText("")
		button.glowHost:Hide()
		if set.glowGate then
			-- the sensor only draws while the unit has the HoT; the gate
			-- hides it unless the unit is missing at least the heal
			-- (friendliness can be secret in combat; the HoT implies it)
			local exists = UnitExists(unit)
			if cfg.overhealGlow and (IsSecret(exists) or exists) then
				ns.Overheal.UpdateGate(set.glowGate, unit, true, 0)
			else
				set.glowGate.clip:SetAlpha(0)
			end
		end
		if onCD then button:SetAlpha(cfg.cooldownAlpha) else button:SetAlpha(1) end
		return
	end

	button.tex:Show()
	button.tex:SetAlpha(1)
	local can, aura = false, nil
	if helpable then
		can, aura = ns.Evaluate(unit)
	end

	if can then
		if onCD then button:SetAlpha(cfg.cooldownAlpha) else button:SetAlpha(1) end
		ApplyLook(button.tex, state)
		button.cooldown:SetAlpha(spiral and 1 or 0)
		local name = UnitName(unit)
		button.label:SetText(not IsSecret(name) and name or "")
		local left = ns.Remaining(aura)
		button.timer:SetText(cfg.showTimer and left and string.format("%d", left + 0.5) or "")
		button.glowHost:SetShown(cfg.overhealGlow and ns.Overheal.Fits(unit) == true)
	else
		button.glowHost:Hide()
		-- greyed when the target has no HoT (or there's no target)
		if not cfg.locked then
			button:SetAlpha(0.6)
		elseif cfg.showInactive then
			if onCD then button:SetAlpha(cfg.cooldownAlpha) else button:SetAlpha(1) end
		else
			button:SetAlpha(0)
		end
		ApplyLook(button.tex, "unusable")
		button.cooldown:SetAlpha(spiral and cfg.showInactive and 1 or 0)
		button.label:SetText("")
		button.timer:SetText("")
	end
end

function Icon:Flush()
	if pendingStyle then StyleNatives() end
end

-- Same "target" token, different unit: make the sensors re-read it.
function Icon:TargetChanged()
	if not (button and button.sensors) then return end
	local set = button.sets.target
	for _, sensor in pairs(set.sensors) do ns.Native.Update(sensor) end
	if set.glowSensor then ns.Native.Update(set.glowSensor) end
	if ns.Native.Mutable() then
		for _, b in pairs(set.natives) do b.smLabel:SetText(UnitName("target")) end
	end
end

function Icon:RefreshUnit()
	self:Refresh()
end

function Icon:UpdateCooldown()
	if not button then return end
	local spell = SwiftmendSpell()
	local cd = button.cooldown
	local info = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spell)
	if IsSecret(info) then info = nil end
	if info then
		local start, duration, gcd = info.startTime, info.duration, info.isOnGCD
		if not IsSecret(start) and not IsSecret(duration) then
			-- skip the global cooldown so only Swiftmend's own cooldown spins
			if duration and duration > 1.5 then cd:SetCooldown(start, duration) else cd:SetCooldown(0, 0) end
		elseif not IsSecret(gcd) and gcd then
			cd:SetCooldown(0, 0)
		elseif C_Spell.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject then
			-- secret times in combat: let the widget read a duration object
			local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, spell)
			if ok and not IsSecret(dur) and dur ~= nil then
				pcall(cd.SetCooldownFromDurationObject, cd, dur)
			end
		else
			-- the cooldown widget accepts secret numbers
			pcall(cd.SetCooldown, cd, start, duration)
		end
	elseif GetSpellCooldown then
		local start, duration = GetSpellCooldown(spell)
		if start and duration and duration > 1.5 then cd:SetCooldown(start, duration) else cd:SetCooldown(0, 0) end
	end
	self:Refresh()
end

-- Shared with the raid-frame markers.
function Icon.SwiftmendOnCooldown()
	if not button then return false end
	return OnCooldown(SwiftmendSpell())
end

function Icon:Init()
	Create()
	self:Layout()
	self:UpdateCooldown()
end

function Icon:ResetPosition()
	ns.db.icon.point = { "CENTER", "UIParent", "CENTER", 0, -150 }
	self:Layout()
end

ns.RegisterModule(Icon)
