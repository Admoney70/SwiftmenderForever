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

-- Some frames (protected ones, or ones restricted by the secret-value
-- rules) error on any method call from addon code even though they don't
-- report IsForbidden, so every read of a frame we don't own is guarded.
local function Usable(frame)
	if type(frame) ~= "table" then return false end
	if frame.IsForbidden then
		local ok, forbidden = pcall(frame.IsForbidden, frame)
		if not ok or forbidden then return false end
	end
	return true
end

local function SafeName(frame)
	if not frame.GetName then return end
	local ok, name = pcall(frame.GetName, frame)
	if ok and not IsSecret(name) then return name end
end

local function SafeChildren(frame)
	if not frame.GetChildren then return {} end
	local result = { pcall(frame.GetChildren, frame) }
	if not table.remove(result, 1) then return {} end
	return result
end

local function ReadUnit(frame)
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

local function FrameUnit(frame)
	local ok, unit = pcall(ReadUnit, frame)
	if ok then return unit end
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
		-- native sensor (see Overheal.CreateGate)
		o.gate = ns.Overheal.CreateGate(o, 40)
		-- the normal marker look, hidden while a cooldown timer replaces it
		o.look = CreateFrame("Frame", nil, o.gate.clip)
		o.look:SetAllPoints(o)
		o.sensor = ns.Native.CreateSensor(o.look, o.smUnit, function(button) DecorateNative(o, button) end)
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

--------------------------------------------------------------------------
-- Swiftmend cooldown: fade or timer
--------------------------------------------------------------------------
-- While Swiftmend is on cooldown the marker can fade ("Fade"), be replaced
-- by the seconds left ("Timer"), or stay as it is ("None").
--
-- In native mode the game refuses text changes inside aura buttons while
-- auras are secret, so the countdown can't be written in combat. Instead
-- each raid frame gets one aura sensor per second of the cooldown, each
-- button showing a fixed number ("15", "14", ... "1") set out of combat.
-- The game shows them only on players with the HoT, like the marker, and
-- the countdown just makes the proxy frame (ours) for the current second
-- visible, which works in combat. o.look (the normal marker) and o.cdLook
-- (the numbers) swap while Swiftmend is on cooldown.
--
-- Everything swaps by alpha, never by hiding: a hidden aura container stops
-- tracking, and when shown again the game redraws its button a moment
-- later, which made the countdown flicker every second.

local STYLES = { "Fade", "Timer", "None" }
Frames.COOLDOWN_STYLES = STYLES
local MAX_SECONDS = 30

function Frames.CooldownStyle()
	local style = ns.db.overlay.onCooldown
	for _, v in ipairs(STYLES) do
		if v == style then return v end
	end
	return "Fade"
end

-- Whole seconds left (rounded up), or nil when unknown.
local function SecondsLeft()
	local left = ns.Icon.SwiftmendRemaining()
	if not left then return end
	return math.max(1, math.ceil(left))
end

-- How many number sensors a frame needs.
local function CountdownSeconds()
	local length = ns.Icon.SwiftmendCooldownLength() or 15
	return math.min(MAX_SECONDS, math.max(1, math.ceil(length)))
end

local function TimerFontSize()
	return math.max(8, math.floor(ns.db.overlay.size * 0.7 + 0.5))
end

-- A number sensor's button: just its number, where the marker is.
local function DecorateNumber(o, button, n)
	o.numButtons[n] = button
	if button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
	if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
	local cfg = ns.db.overlay
	button:ClearAllPoints()
	button:SetSize(cfg.size, cfg.size)
	button:SetPoint(cfg.point, o, cfg.point, cfg.offsetX, cfg.offsetY)
	if not button.smNumber then
		button.smNumber = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		button.smNumber:SetPoint("CENTER", button, "CENTER", 0, 0)
	end
	local font = button.smNumber:GetFont() or STANDARD_TEXT_FONT
	if font then button.smNumber:SetFont(font, TimerFontSize(), "OUTLINE") end
	button.smNumber:SetText(tostring(n))
end

-- Legacy (out-of-combat) overlays get a plain text layer of ours.
local function LayoutLegacyTimer(o)
	local cfg, L = ns.db.overlay, o.timerLayer
	L.marker:ClearAllPoints()
	L.marker:SetSize(cfg.size, cfg.size)
	L.marker:SetPoint(cfg.point, o, cfg.point, cfg.offsetX, cfg.offsetY)
	local font = L.text:GetFont() or STANDARD_TEXT_FONT
	if font then L.text:SetFont(font, TimerFontSize(), "OUTLINE") end
end

-- Builds (or extends) the countdown the first time the Timer style is used.
local function EnsureTimer(o)
	if o.sensor then
		if not o.cdLook then
			o.cdLook = CreateFrame("Frame", nil, o.gate.clip)
			o.cdLook:SetAllPoints(o)
			o.cdLook:SetAlpha(0)
			o.numbers, o.numSensors, o.numButtons = {}, {}, {}
		end
		for n = #o.numbers + 1, CountdownSeconds() do
			local proxy = CreateFrame("Frame", nil, o.cdLook)
			proxy:SetAllPoints(o)
			proxy:SetAlpha(0)
			o.numbers[n] = proxy
			o.numSensors[n] = ns.Native.CreateSensor(proxy, o.smUnit, function(button) DecorateNumber(o, button, n) end)
		end
		return
	end
	if o.timerLayer then return end
	local L = CreateFrame("Frame", nil, o)
	L:SetAllPoints(o)
	L.marker = CreateFrame("Frame", nil, L)
	L.text = L:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	L.text:SetPoint("CENTER", L.marker, "CENTER", 0, 0)
	L:Hide()
	o.timerLayer = L
	LayoutLegacyTimer(o)
end

-- Shows the right second (native) or writes it (legacy).
local function ShowSecond(o, n)
	if o.numbers then
		n = math.min(n, #o.numbers)
		if o.shownSecond == n then return end
		if o.shownSecond and o.numbers[o.shownSecond] then o.numbers[o.shownSecond]:SetAlpha(0) end
		o.numbers[n]:SetAlpha(1)
		o.shownSecond = n
	elseif o.timerLayer then
		o.timerLayer.text:SetText(tostring(n))
	end
end

-- Steps every shown countdown a few times a second.
local shownTimers = {}
local ticker = CreateFrame("Frame")
ticker.elapsed = 0
ticker:SetScript("OnUpdate", function(self, elapsed)
	self.elapsed = self.elapsed + elapsed
	if self.elapsed < 0.1 then return end
	self.elapsed = 0
	if not next(shownTimers) then return end
	local n = SecondsLeft()
	if not n then
		Frames:Refresh()
		return
	end
	for o in pairs(shownTimers) do ShowSecond(o, n) end
end)

-- Legacy overlays draw the normal look straight on the overlay.
local function SetLegacyLook(o, shown)
	local cfg = ns.db.overlay
	o.icon:SetShown(shown and cfg.showIcon)
	o.timer:SetShown(shown and cfg.showIcon and cfg.showTimer)
	if not shown then o.spiral:Hide() end
	for i = 1, 4 do
		o.edges[i]:SetShown(shown and cfg.showBorder and true or false)
		o.iconEdges[i]:SetShown(shown and cfg.showIcon and cfg.showIconBorder and true or false)
	end
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
	if not frame or overlays[frame] or not Usable(frame) then return end
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
-- (The Timer style falls back to fading while the time left is unknown.)
local function ApplyFade(o, timerShown)
	local cfg = ns.db.overlay
	local target = o.look or o
	if o.look and timerShown then
		-- the countdown replaces the marker (alpha, not Hide: see above)
		target:SetAlpha(0)
		return
	end
	local style = Frames.CooldownStyle()
	local fade = style == "Fade" or (style == "Timer" and not timerShown)
	if fade and onCooldown then target:SetAlpha(cfg.cooldownAlpha) else target:SetAlpha(1) end
end

-- Swaps between the normal look and the countdown; true when it shows.
local function ApplyTimer(o)
	local timer = Frames.CooldownStyle() == "Timer"
	if timer then EnsureTimer(o) end
	local seconds = timer and onCooldown and SecondsLeft()
	local active = seconds and true or false
	if active then
		ShowSecond(o, seconds)
		shownTimers[o] = true
	else
		shownTimers[o] = nil
	end
	if o.sensor then
		if o.cdLook then o.cdLook:SetAlpha(active and 1 or 0) end
	else
		if o.timerLayer then o.timerLayer:SetShown(active) end
		o.timerActive = active
	end
	return active
end

function Frames:UpdateFrame(frame)
	local o = overlays[frame]
	if not o then return end
	ApplyFade(o, ApplyTimer(o))
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
			for _, sensor in pairs(o.numSensors or {}) do ns.Native.SetUnit(sensor, unit) end
		end
		ns.Overheal.UpdateUnit(unit) -- caches max health for the fallback
		ns.Overheal.UpdateGate(o.gate, unit, ns.db.overlay.noOverheal, 1)
		o:Show()
		return
	end
	local can, aura = ns.Evaluate(unit)
	if can and ns.Overheal.Allows(unit) then
		local left = ns.db.overlay.showTimer and ns.Remaining(aura)
		o.timer:SetText(left and left < 10 and string.format("%d", left + 0.5) or "")
		UpdateSpiral(o, unit, aura)
		SetLegacyLook(o, not o.timerActive)
		o:Show()
	else
		o:Hide()
	end
end

-- Walk a named frame and (for group headers) its unnamed children looking
-- for unit buttons.
local function Consider(frame, provider, depth)
	if not Usable(frame) or frame.smOverlay then return end
	if FrameUnit(frame) then
		Frames:Attach(frame, provider)
	end
	if depth > 0 then
		for _, child in ipairs(SafeChildren(frame)) do
			Consider(child, provider, depth - 1)
		end
	end
end

-- The game has thousands of frames (each aura display adds more), and one
-- pass over all of them can hit the "script ran too long" limit, so walks
-- look at a batch per frame and pick up where they left off.
local SCAN_BATCH = 250

local function WalkFrames(visit, done)
	local frame = EnumerateFrames()
	local function step()
		local n = 0
		while frame and n < SCAN_BATCH do
			if Usable(frame) then visit(frame) end
			frame = EnumerateFrames(frame)
			n = n + 1
		end
		if frame then
			C_Timer.After(0, step)
		elseif done then
			done()
		end
	end
	step()
end

local scanning, scanAgain
function Frames:ScanNow()
	if not ns.db then return end
	if scanning then
		scanAgain = true
		return
	end
	scanning = true
	WalkFrames(function(frame)
		local provider = ProviderFor(SafeName(frame))
		if provider then Consider(frame, provider, 3) end
	end, function()
		scanning = nil
		if scanAgain then
			scanAgain = nil
			Frames:ScanNow()
		else
			Frames:Refresh()
		end
	end)
end

-- Debug helper: list named frames with a group unit that we did NOT match,
-- so users can find out what a raid-frame addon calls its frames.
function Frames:ListUnmatched()
	local seen, n = {}, 0
	WalkFrames(function(frame)
		local name = SafeName(frame)
		if name and not overlays[frame] and FrameUnit(frame) then
			local prefix = name:match("^(%a+)") or name
			if not seen[prefix] then
				seen[prefix] = true
				n = n + 1
				ns.Print(string.format("  %s (unit %s)", name, FrameUnit(frame)))
			end
		end
	end, function()
		if n == 0 then ns.Print("  no unmatched unit frames found") end
	end)
end

-- /sm debug: what the cooldown timer and overheal gate can see in game.
function Frames:Debug()
	local cfg = ns.db.overlay
	local left = ns.Icon.SwiftmendRemaining()
	ns.Print(string.format("on cooldown %s (%s s left), on-cooldown style %s, overheal filter %s (heal %s)",
		tostring(onCooldown), left and string.format("%.1f", left) or "?", Frames.CooldownStyle(),
		tostring(cfg.noOverheal), tostring((ns.Overheal.HealAmount()))))
	print("  UnitHealthMissing " .. (UnitHealthMissing and "yes" or "no")
		.. ", AuraContainer " .. (ns.Native.Available() and "yes" or "no"))
	print(string.format("  countdown length %s s, seconds left %s",
		tostring((ns.Icon.SwiftmendCooldownLength())), tostring((SecondsLeft()))))
	local n, sample = 0, nil
	for frame, o in pairs(overlays) do
		sample = sample or o.button
		n = n + 1
		if n <= 4 then
			local made = 0
			for _ in pairs(o.numButtons or {}) do made = made + 1 end
			print(string.format("  %s (%s): marker button %s, countdown sensors %d (buttons made %d), showing second %s, countdown shown %s, marker shown %s",
				SafeName(frame) or "?", tostring(o.smUnit), tostring(o.button ~= nil), o.numbers and #o.numbers or 0,
				made, tostring(o.shownSecond), tostring(o.cdLook and o.cdLook:GetAlpha() == 1 or false),
				tostring(o.look and o.look:GetAlpha() > 0 or false)))
		end
	end
	print(string.format("  %d raid frames hooked", n))
	-- the native aura button's methods, to see what this client offers
	if sample then
		local names = {}
		local mt = getmetatable(sample)
		local index = mt and type(mt.__index) == "table" and mt.__index
		if index then
			for k in pairs(index) do
				if type(k) == "string" and (k:find("Duration") or k:find("^SetIcon") or k:find("Application")) then
					names[#names + 1] = k
				end
			end
		end
		table.sort(names)
		print("  aura button methods: " .. (#names > 0 and table.concat(names, ", ") or "none found (or not listable)"))
	else
		print("  no aura button yet: put your HoT on someone, then run /sm debug again")
	end
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
		if mutable and o.numButtons then
			for n, button in pairs(o.numButtons) do DecorateNumber(o, button, n) end
		end
		if o.timerLayer then LayoutLegacyTimer(o) end
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
			elseif Usable(frame) and FrameUnit(frame) then
				local provider = ProviderFor(SafeName(frame))
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
