-- Swiftmender Forever: settings window, opened with /sm.

local ADDON, ns = ...

local Config = {}
ns.Config = Config

local window
local controls = {}   -- each has :Sync() to re-read the saved value

local POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

local function Changed(what)
	if what == "icon" then
		ns.Icon:Layout()
	elseif what == "frames" then
		ns.Frames:Relayout()
	elseif what == "filters" then
		ns.Native.RefreshFilters()
		ns.RefreshAll()
	else
		ns.RefreshAll()
	end
end

--------------------------------------------------------------------------
-- widgets
--------------------------------------------------------------------------

local function Header(parent, text, y)
	local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fs:SetPoint("TOPLEFT", 16, y)
	fs:SetText(text)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 0.82, 0, 0.25)
	line:SetHeight(1)
	line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
	line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
	return y - 22
end

local function Check(parent, label, y, get, set, what)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb:SetPoint("TOPLEFT", 20, y)
	cb.label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	cb.label:SetText(label)
	cb:SetHitRectInsets(0, -(cb.label:GetStringWidth() + 8), 0, 0)
	cb:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		Changed(what)
		Config:Sync()
	end)
	function cb:Sync() self:SetChecked(get()) end
	controls[#controls + 1] = cb
	return cb, y - 26
end

local function Slider(parent, label, y, min, max, step, get, set, what, fmt)
	local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
	s:SetOrientation("HORIZONTAL")
	s:SetSize(200, 16)
	s:SetPoint("TOPLEFT", 26, y - 16)
	s:SetMinMaxValues(min, max)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	s:SetBackdrop({
		bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
		edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
		tile = true, tileSize = 8, edgeSize = 8,
		insets = { left = 3, right = 3, top = 6, bottom = 6 },
	})
	s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

	s.label = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	s.label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 2)
	s.label:SetText(label)
	s.value = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	s.value:SetPoint("LEFT", s, "RIGHT", 10, 0)

	fmt = fmt or "%d"
	s:SetScript("OnValueChanged", function(self, v, userInput)
		self.value:SetText(string.format(fmt, v))
		if userInput then
			set(v)
			Changed(what)
		end
	end)
	function s:Sync()
		self:SetValue(get())
		self.value:SetText(string.format(fmt, get()))
	end
	controls[#controls + 1] = s
	return s, y - 42
end

local function Button(parent, text, width)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width or 120, 22)
	b:SetText(text)
	return b
end

-- "< TOPRIGHT >" picker, avoids the deprecated dropdown menus.
local function Cycle(parent, label, y, values, get, set, what)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(260, 22)
	f:SetPoint("TOPLEFT", 26, y)
	local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	text:SetPoint("LEFT")
	text:SetText(label)
	local prev = Button(f, "<", 24)
	prev:SetPoint("LEFT", 70, 0)
	f.value = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	f.value:SetPoint("LEFT", prev, "RIGHT", 4, 0)
	f.value:SetWidth(110)
	local nextB = Button(f, ">", 24)
	nextB:SetPoint("LEFT", f.value, "RIGHT", 4, 0)

	local function Step(dir)
		local cur = get()
		local idx = 1
		for i, v in ipairs(values) do if v == cur then idx = i end end
		idx = (idx - 1 + dir) % #values + 1
		set(values[idx])
		Changed(what)
		f:Sync()
	end
	prev:SetScript("OnClick", function() Step(-1) end)
	nextB:SetScript("OnClick", function() Step(1) end)
	function f:Sync() self.value:SetText(get()) end
	controls[#controls + 1] = f
	return f, y - 28
end

--------------------------------------------------------------------------
-- window
--------------------------------------------------------------------------

local function Build()
	local db = function() return ns.db end

	local ok, f = pcall(CreateFrame, "Frame", "SwiftmenderForeverConfig", UIParent, "BasicFrameTemplateWithInset")
	if not ok then
		f = CreateFrame("Frame", "SwiftmenderForeverConfig", UIParent, "BackdropTemplate")
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
		local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -4, -4)
	end
	f:SetSize(340, 700)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	tinsert(UISpecialFrames, "SwiftmenderForeverConfig")   -- Esc closes it

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -6)
	title:SetText("Swiftmender Forever")

	local y = -34

	-- Target icon ---------------------------------------------------------
	y = Header(f, "Target icon", y)
	_, y = Check(f, "Show the target icon", y,
		function() return db().icon.enabled end,
		function(v) db().icon.enabled = v end, "icon")
	_, y = Check(f, "Lock position (unlock to drag it)", y,
		function() return db().icon.locked end,
		function(v) db().icon.locked = v end, "icon")
	_, y = Check(f, "Hide if I don't know Swiftmend", y,
		function() return db().icon.onlyWhenKnown end,
		function(v) db().icon.onlyWhenKnown = v end, "icon")
	_, y = Slider(f, "Icon size", y, 16, 128, 1,
		function() return db().icon.size end,
		function(v) db().icon.size = v end, "icon")
	_, y = Slider(f, "Opacity while Swiftmend is on cooldown", y, 0, 1, 0.05,
		function() return db().icon.cooldownAlpha end,
		function(v) db().icon.cooldownAlpha = v end, "icon", "%.2f")
	local resetPos = Button(f, "Reset position", 130)
	resetPos:SetPoint("TOPLEFT", 26, y)
	resetPos:SetScript("OnClick", function() ns.Icon:ResetPosition() end)
	y = y - 34

	-- Raid frames ---------------------------------------------------------
	y = Header(f, "Raid frames", y)
	f.blizz, y = Check(f, "Blizzard raid frames", y,
		function() return db().overlay.blizzard end,
		function(v) db().overlay.blizzard = v end)
	f.buzz, y = Check(f, "Buzzard Frames", y,
		function() return db().overlay.buzzard end,
		function(v) db().overlay.buzzard = v end)
	_, y = Check(f, "Show Swiftmend marker icon", y,
		function() return db().overlay.showIcon end,
		function(v) db().overlay.showIcon = v end, "frames")
	_, y = Check(f, "Show HoT duration spiral on the marker", y,
		function() return db().overlay.showSpiral end,
		function(v) db().overlay.showSpiral = v end, "frames")
	_, y = Check(f, "Show countdown timer on the marker", y,
		function() return db().overlay.showTimer end,
		function(v) db().overlay.showTimer = v end, "frames")
	_, y = Check(f, "Show green border", y,
		function() return db().overlay.showBorder end,
		function(v) db().overlay.showBorder = v end, "frames")
	_, y = Slider(f, "Marker size", y, 6, 40, 1,
		function() return db().overlay.size end,
		function(v) db().overlay.size = v end, "frames")
	_, y = Cycle(f, "Position", y, POINTS,
		function() return db().overlay.point end,
		function(v) db().overlay.point = v end, "frames")
	_, y = Slider(f, "X offset", y, -30, 30, 1,
		function() return db().overlay.offsetX end,
		function(v) db().overlay.offsetX = v end, "frames")
	_, y = Slider(f, "Y offset", y, -30, 30, 1,
		function() return db().overlay.offsetY end,
		function(v) db().overlay.offsetY = v end, "frames")

	-- General -------------------------------------------------------------
	y = Header(f, "General", y)
	_, y = Check(f, "Only count my own Rejuvenation / Regrowth", y,
		function() return db().onlyMine end,
		function(v) db().onlyMine = v end, "filters")

	local rescan = Button(f, "Rescan frames", 130)
	rescan:SetPoint("TOPLEFT", 26, y - 4)
	rescan:SetScript("OnClick", function()
		ns.Frames:ScanNow()
		ns.RefreshAll()
		Config:Sync()
	end)
	local reset = Button(f, "Reset all", 130)
	reset:SetPoint("LEFT", rescan, "RIGHT", 10, 0)
	reset:SetScript("OnClick", function()
		ns.ResetDB()
		ns.Icon:Layout()
		ns.Frames:Relayout()
		Config:Sync()
		ns.Print("settings reset")
	end)

	f.status = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	f.status:SetPoint("BOTTOMLEFT", 16, 12)
	f.status:SetPoint("BOTTOMRIGHT", -16, 12)
	f.status:SetJustifyH("LEFT")

	f:SetScript("OnShow", function() Config:Sync() end)
	window = f
end

function Config:Sync()
	if not window then return end
	for _, c in ipairs(controls) do c:Sync() end
	local counts = ns.Frames:Count()
	window.blizz.label:SetText(string.format("Blizzard raid frames |cff888888(%d hooked)|r", counts.blizzard or 0))
	window.buzz.label:SetText(string.format("Buzzard Frames |cff888888(%d hooked)|r", counts.buzzard or 0))
	window.status:SetText("Knows Swiftmend: " .. (ns.KnowsSwiftmend() and "|cff33ff33yes|r" or "|cffff3333no|r")
		.. "   Combat tracking: " .. (ns.Native.Available() and "|cff33ff33native|r" or "|cffff3333unavailable|r")
		.. "\n|cff888888/sm help for commands|r")
end

function Config:Toggle()
	if not window then Build() end
	window:SetShown(not window:IsShown())
end

-- Also reachable from Esc > Options > AddOns.
function Config:Init()
	if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
	local panel = CreateFrame("Frame")
	local open = Button(panel, "Open Swiftmender settings", 220)
	open:SetPoint("TOPLEFT", 16, -16)
	open:SetScript("OnClick", function()
		if SettingsPanel then HideUIPanel(SettingsPanel) end
		if not window then Build() end
		window:Show()
	end)
	pcall(function()
		local category = Settings.RegisterCanvasLayoutCategory(panel, "Swiftmender Forever")
		Settings.RegisterAddOnCategory(category)
	end)
end

ns.RegisterModule(Config)
