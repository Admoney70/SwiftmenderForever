-- Swiftmender Forever: raid-frame overlays.
-- Puts a Swiftmend marker (icon + coloured border) on Blizzard compact
-- raid/party frames and on Buzzard Frames whenever that unit can be
-- Swiftmended.

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

local function CreateEdge(o)
	local t = o:CreateTexture(nil, "OVERLAY", nil, 6)
	t:SetColorTexture(1, 1, 1, 1)
	return t
end

local function LayoutOverlay(o)
	local cfg = ns.db.overlay
	local size = cfg.size

	o.icon:ClearAllPoints()
	o.icon:SetSize(size, size)
	o.icon:SetPoint(cfg.point, o, cfg.point, cfg.offsetX, cfg.offsetY)
	o.icon:SetShown(cfg.showIcon)

	local r, g, b, a = unpack(cfg.borderColor)
	local t = 2
	local e = o.edges
	e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(t)
	e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(t)
	e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(t)
	e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(t)
	for i = 1, 4 do
		e[i]:SetVertexColor(r, g, b, a)
		e[i]:SetShown(cfg.showBorder)
	end
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

	o.icon = o:CreateTexture(nil, "OVERLAY", nil, 7)
	o.icon:SetTexture(ns.SpellTexture(ns.SPELLS.SWIFTMEND))
	o.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	o.timer = o:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	o.timer:SetPoint("CENTER", o.icon, "CENTER", 0, 0)

	o.edges = { CreateEdge(o), CreateEdge(o), CreateEdge(o), CreateEdge(o) }
	LayoutOverlay(o)
	o:Hide()
	return o
end

function Frames:Attach(frame, provider)
	if not frame or overlays[frame] then return end
	if frame.IsForbidden and frame:IsForbidden() then return end
	local o = CreateOverlay(frame, provider)
	if o then
		overlays[frame] = o
		self:UpdateFrame(frame)
	end
end

function Frames:UpdateFrame(frame)
	local o = overlays[frame]
	if not o then return end
	local enabled = ns.db.overlay[o.provider]
	local unit = enabled and frame:IsVisible() and FrameUnit(frame)
	if not unit then
		o:Hide()
		return
	end
	local can, aura = ns.Evaluate(unit)
	if can then
		local left = ns.Remaining(aura)
		o.timer:SetText(left and left < 10 and ns.db.overlay.showIcon and string.format("%d", left + 0.5) or "")
		o:Show()
	else
		o:Hide()
	end
end

-- Walk a named frame and (for group headers) its unnamed children looking
-- for unit buttons.
local function Consider(frame, provider, depth)
	if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
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

function Frames:Relayout()
	for _, o in pairs(overlays) do LayoutOverlay(o) end
	self:Refresh()
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
	for frame in pairs(overlays) do self:UpdateFrame(frame) end
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
