-- Swiftmender Forever: raid-frame overlays.
-- Puts a Swiftmend marker (icon + coloured border) on Blizzard compact
-- raid/party frames and on Buzzard Frames whenever that unit can be
-- Swiftmended. Uses a native aura sensor (Native.lua) so it keeps working in
-- combat; the Lua aura scan below is only a fallback for clients without
-- Blizzard_AuraContainer.

local ADDON, ns = ...
local IsSecret = ns.IsSecret

local Frames = {}
ns.Frames = Frames

local overlays = {}   -- [unitFrame] = overlay
local providers = { "blizzard", "buzzard" }

local function FrameUnit(frame)
	local unit = frame.displayedUnit
	if IsSecret(unit) then return end
	if unit == nil then unit = frame.unit end
	if IsSecret(unit) then return end
	if unit == nil and frame.GetAttribute then
		local ok, attr = pcall(frame.GetAttribute, frame, "unit")
		if ok then unit = attr end
	end
	if IsSecret(unit) or type(unit) ~= "string" then return end
	-- skip pets, nameplates, arena, boss frames etc.
	if unit == "player" or unit:match("^party%d+$") or unit:match("^raid%d+$") then
		return unit
	end
end

local function ProviderFor(name)
	if type(name) ~= "string" or IsSecret(name) then return end
	local patterns = ns.db.overlay.patterns
	for _, provider in ipairs(providers) do
		for _, pat in ipairs(patterns[provider] or {}) do
			local ok, match = pcall(string.match, name, pat)
			if ok and match then return provider end
		end
	end
end

local function LayoutOverlay(o)
	local cfg = ns.db.overlay
	local size = cfg.size

	o.icon:ClearAllPoints()
	o.icon:SetSize(size, size)
	o.icon:SetPoint(cfg.point, o, cfg.point, cfg.offsetX, cfg.offsetY)
	o.icon:SetShown(cfg.showIcon)
	o.spiral:ClearAllPoints()
	o.spiral:SetAllPoints(o.icon)
	o.spiralKey = nil
	if not (cfg.showIcon and cfg.showSpiral) then o.spiral:Hide() end
	o.timer:SetShown(cfg.showIcon and cfg.showTimer)

	ns.LayoutEdges(o.edges, o, cfg.borderSize, cfg.borderColor, cfg.showBorder)
	ns.LayoutEdges(o.iconEdges, o.icon, cfg.iconBorderSize, cfg.iconBorderColor,
		cfg.showIcon and cfg.showIconBorder, true)
end

-- Styles the native slot button. Runs inside initializeFrame (every time
-- Blizzard recreates the button) and on settings changes while mutable.
local function DecorateNative(o, button)
	local cfg = ns.db.overlay
	o.button = button
	if button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
	if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end

	if not button.smIcon then
		button.smIcon = button:CreateTexture(nil, "ARTWORK")
		button.smIcon:SetAllPoints(button)
		button.smIcon:SetTexture(ns.SpellTexture(ns.SPELLS.SWIFTMEND))
		button.smIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

		local spiral = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
		spiral:SetAllPoints(button)
		spiral:SetReverse(true)
		spiral:SetDrawEdge(false)
		spiral:SetDrawBling(false)
		spiral:SetHideCountdownNumbers(true)
		button.smSpiral = spiral

		local textHost = CreateFrame("Frame", nil, button)
		textHost:SetAllPoints(button)
		textHost:SetFrameLevel(spiral:GetFrameLevel() + 2)
		button.smTimer = textHost:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		button.smTimer:SetPoint("CENTER", button, "CENTER", 0, 0)

		button.smEdges = ns.CreateEdges(button)
		button.smIconEdges = ns.CreateEdges(textHost, 5)
	end

	button:ClearAllPoints()
	button:SetSize(cfg.size, cfg.size)
	button:SetPoint(cfg.point, o, cfg.point, cfg.offsetX, cfg.offsetY)
	button.smIcon:SetShown(cfg.showIcon)

	if cfg.showIcon and cfg.showSpiral then
		button.smSpiral:Show()
		button:SetDurationCooldown(button.smSpiral)
	else
		button:ClearDurationCooldown()
		button.smSpiral:Hide()
	end
	if cfg.showIcon and cfg.showTimer then
		button.smTimer:Show()
		button:SetDurationText(button.smTimer, ns.Native.TimerOptions())
	else
		button:ClearDurationText()
		button.smTimer:Hide()
	end

	-- the border hangs off the native button (so it shares its visibility)
	-- but outlines the whole raid frame
	ns.LayoutEdges(button.smEdges, o, cfg.borderSize, cfg.borderColor, cfg.showBorder)
	ns.LayoutEdges(button.smIconEdges, button, cfg.iconBorderSize, cfg.iconBorderColor,
		cfg.showIcon and cfg.showIconBorder, true)
end

local function CreateOverlay(frame, provider)
	-- Overlays are plain (insecure) children: they never touch the
	-- secure frame's attributes, so this is safe even in combat.
	local ok, o = pcall(CreateFrame, "Frame", nil, frame)
	if not ok or not o then return end
	o:SetAllPoints(frame)
	o:SetFrameLevel(frame:GetFrameLevel() + 20)
	o:EnableMouse(false)
	o.provider = provider
	o.smOverlay = true

	if ns.Native.Available() then
		o.smUnit = FrameUnit(frame) or "player"
		-- the overheal gate sits between our overlay (cooldown fade) and the
		-- native sensor; its alpha may be a secret curve result
		o.gate = CreateFrame("Frame", nil, o)
		o.gate:SetAllPoints(o)
		o.sensor = ns.Native.CreateSensor(o.gate, o.smUnit, function(button) DecorateNative(o, button) end)
		if o.sensor then return o end
	end

	o.icon = o:CreateTexture(nil, "OVERLAY", nil, 7)
	o.icon:SetTexture(ns.SpellTexture(ns.SPELLS.SWIFTMEND))
	o.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- HoT duration spiral over the marker icon
	o.spiral = CreateFrame("Cooldown", nil, o, "CooldownFrameTemplate")
	o.spiral:SetReverse(true)
	o.spiral:SetDrawEdge(false)
	o.spiral:SetHideCountdownNumbers(true)
	o.spiral:Hide()

	-- the timer sits above the spiral
	local text = CreateFrame("Frame", nil, o)
	text:SetAllPoints(o)
	text:SetFrameLevel(o.spiral:GetFrameLevel() + 2)
	o.timer = text:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	o.timer:SetPoint("CENTER", o.icon, "CENTER", 0, 0)
	o.iconEdges = ns.CreateEdges(text, 5)

	o.edges = ns.CreateEdges(o)
	LayoutOverlay(o)
	o:Hide()
	return o
end

-- Placement preview: while the settings window is open every hooked raid
-- frame shows a ghost marker at the configured spot, so size, position and
-- offsets can be tuned without anyone having a HoT. It is a plain frame on
-- the raid frame (not the native button), so it can be shown at any time.
local previewing = false

local function LayoutPreview(o)
	local cfg = ns.db.overlay
	local p = o.preview
	if not p then
		local frame = o:GetParent()
		p = CreateFrame("Frame", nil, frame)
		p:SetFrameLevel(frame:GetFrameLevel() + 25)
		p:EnableMouse(false)
		p.icon = p:CreateTexture(nil, "ARTWORK")
		p.icon:SetTexture(ns.SpellTexture(ns.SPELLS.SWIFTMEND))
		p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		p.icon:SetAlpha(0.8)
		p.iconEdges = ns.CreateEdges(p, 5)
		p.edges = ns.CreateEdges(p)
		o.preview = p
	end
	p:ClearAllPoints()
	p:SetAllPoints(o)
	p.icon:ClearAllPoints()
	p.icon:SetSize(cfg.size, cfg.size)
	p.icon:SetPoint(cfg.point, p, cfg.point, cfg.offsetX, cfg.offsetY)
	p.icon:SetShown(cfg.showIcon)
	ns.LayoutEdges(p.iconEdges, p.icon, cfg.iconBorderSize, cfg.iconBorderColor,
		cfg.showIcon and cfg.showIconBorder, true)
	ns.LayoutEdges(p.edges, p, cfg.borderSize, cfg.borderColor, cfg.showBorder)
	p:SetShown(previewing and ns.db.overlay[o.provider] and true or false)
end

function Frames:SetPreview(on)
	previewing = on and true or false
	for _, o in pairs(overlays) do
		if previewing or o.preview then LayoutPreview(o) end
	end
end

function Frames:Attach(frame, provider)
	if not frame or overlays[frame] then return end
	if frame.IsForbidden and frame:IsForbidden() then return end
	local o = CreateOverlay(frame, provider)
	if o then
		overlays[frame] = o
		if previewing then LayoutPreview(o) end
		self:UpdateFrame(frame)
	end
end

local function UpdateSpiral(o, unit, aura)
	local cfg = ns.db.overlay
	local cd = o.spiral
	if not (cfg.showIcon and cfg.showSpiral and aura) then
		cd:Hide()
		o.spiralKey = nil
		return
	end
	local exp, dur = aura.expirationTime, aura.duration
	if not IsSecret(exp) and not IsSecret(dur) then
		if not exp or not dur or exp == 0 or dur == 0 then
			cd:Hide()
			o.spiralKey = nil
		elseif o.spiralKey ~= exp then
			o.spiralKey = exp
			cd:SetCooldown(exp - dur, dur)
			cd:Show()
		end
		return
	end
	-- times are secret in combat: hand the widget a duration object instead
	o.spiralKey = nil
	local shown = false
	if C_UnitAuras.GetAuraDuration and cd.SetCooldownFromDurationObject then
		local ok, durObj = pcall(C_UnitAuras.GetAuraDuration, unit, aura.auraInstanceID)
		if ok and not IsSecret(durObj) and durObj ~= nil then
			shown = pcall(cd.SetCooldownFromDurationObject, cd, durObj)
		end
	end
	cd:SetShown(shown)
end

-- Swiftmend cooldown state, refreshed once per Refresh pass.
local onCooldown = false

-- Our overlay frame is addon-owned, so its alpha can change in combat and
-- fades the native marker and borders inside it.
local function ApplyFade(o)
	local cfg = ns.db.overlay
	if cfg.fadeOnCooldown and onCooldown then o:SetAlpha(cfg.cooldownAlpha) else o:SetAlpha(1) end
end

function Frames:UpdateFrame(frame)
	local o = overlays[frame]
	if not o then return end
	ApplyFade(o)
	local enabled = ns.db.overlay[o.provider]
	local unit = enabled and frame:IsVisible() and FrameUnit(frame)
	if not unit then
		o:Hide()
		return
	end
	if o.sensor then
		-- the native button shows itself; we only follow unit changes
		if unit ~= o.smUnit then
			o.smUnit = unit
			ns.Native.SetUnit(o.sensor, unit)
		end
		ns.Overheal.UpdateUnit(unit) -- caches max health while readable
		o.gate:SetAlpha(ns.Overheal.Alpha(unit))
		o:Show()
		return
	end
	local can, aura = ns.Evaluate(unit)
	if can and ns.Overheal.Allows(unit) then
		local left = ns.db.overlay.showTimer and ns.Remaining(aura)
		o.timer:SetText(left and left < 10 and string.format("%d", left + 0.5) or "")
		UpdateSpiral(o, unit, aura)
		o:Show()
	else
		o:Hide()
	end
end

-- Walk a named frame and (for group headers) its unnamed children looking
-- for unit buttons.
local function Consider(frame, provider, depth)
	if not frame or frame.smOverlay or (frame.IsForbidden and frame:IsForbidden()) then return end
	if FrameUnit(frame) then
		Frames:Attach(frame, provider)
	end
	if depth > 0 and frame.GetChildren then
		for _, child in ipairs({ frame:GetChildren() }) do
			Consider(child, provider, depth - 1)
		end
	end
end

function Frames:ScanNow()
	if not ns.db then return end
	local frame = EnumerateFrames()
	while frame do
		if not (frame.IsForbidden and frame:IsForbidden()) then
			local provider = ProviderFor(frame:GetName())
			if provider then Consider(frame, provider, 3) end
		end
		frame = EnumerateFrames(frame)
	end
end

-- Debug helper: list named frames with a group unit that we did NOT match,
-- so users can find out what a raid-frame addon calls its frames.
function Frames:ListUnmatched()
	local seen, n = {}, 0
	local frame = EnumerateFrames()
	while frame do
		if not (frame.IsForbidden and frame:IsForbidden()) then
			local name = frame:GetName()
			if name and not IsSecret(name) and not overlays[frame] and FrameUnit(frame) then
				local prefix = name:match("^(%a+)") or name
				if not seen[prefix] then
					seen[prefix] = true
					n = n + 1
					ns.Print(string.format("  %s (unit %s)", name, FrameUnit(frame)))
				end
			end
		end
		frame = EnumerateFrames(frame)
	end
	if n == 0 then ns.Print("  no unmatched unit frames found") end
end

function Frames:Count()
	local counts = { blizzard = 0, buzzard = 0 }
	for _, o in pairs(overlays) do
		counts[o.provider] = (counts[o.provider] or 0) + 1
	end
	return counts
end

local pendingRelayout
function Frames:Relayout()
	local mutable = ns.Native.Mutable()
	for _, o in pairs(overlays) do
		if o.sensor then
			if mutable and o.button then DecorateNative(o, o.button) end
		else
			LayoutOverlay(o)
		end
	end
	pendingRelayout = not mutable or nil
	if previewing then self:SetPreview(true) end
	self:Refresh()
end

function Frames:Flush()
	if pendingRelayout and ns.Native.Mutable() then self:Relayout() end
end

-- module hooks ------------------------------------------------------------

function Frames:Init()
	-- Blizzard compact frames announce themselves when they get a unit.
	if CompactUnitFrame_SetUnit then
		hooksecurefunc("CompactUnitFrame_SetUnit", function(frame, unit)
			if overlays[frame] then
				Frames:UpdateFrame(frame)
			elseif FrameUnit(frame) then
				local provider = ProviderFor(frame:GetName())
				if provider == "blizzard" then Frames:Attach(frame, provider) end
			end
		end)
	end
	-- Buzzard Frames (or anything else) may load after us.
	C_Timer.After(2, function() Frames:ScanNow() end)
end

function Frames:Refresh()
	onCooldown = ns.Icon.SwiftmendOnCooldown()
	for frame in pairs(overlays) do self:UpdateFrame(frame) end
end

function Frames:UpdateCooldown()
	self:Refresh()
end

function Frames:RefreshUnit(unit)
	for frame in pairs(overlays) do
		if FrameUnit(frame) == unit then self:UpdateFrame(frame) end
	end
end

local lastScan = 0
local pending
function Frames:Scan()
	if pending then return end
	local wait = math.max(0, 1 - (GetTime() - lastScan))
	pending = true
	C_Timer.After(wait, function()
		pending = nil
		lastScan = GetTime()
		Frames:ScanNow()
		Frames:Refresh()
	end)
end

ns.RegisterModule(Frames)
