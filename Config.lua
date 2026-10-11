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

local Button

local function Slider(parent, label, y, min, max, step, get, set, what, fmt, nudge)
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
	if nudge then
		-- -/+ buttons for exact single-step adjustments
		s.value:SetWidth(28)
		local function Step(dir)
			local v = math.max(min, math.min(max, get() + dir * step))
			set(v)
			Changed(what)
			s:Sync()
		end
		local minus = Button(parent, "-", 22)
		minus:SetPoint("LEFT", s.value, "RIGHT", 2, 0)
		minus:SetScript("OnClick", function() Step(-1) end)
		local plus = Button(parent, "+", 22)
		plus:SetPoint("LEFT", minus, "RIGHT", 2, 0)
		plus:SetScript("OnClick", function() Step(1) end)
	end
	controls[#controls + 1] = s
	return s, y - 42
end

function Button(parent, text, width)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width or 120, 22)
	b:SetText(text)
	return b
end

-- "< TOPRIGHT >" picker, avoids the deprecated dropdown menus.
local function Cycle(parent, label, y, values, get, set, what)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(290, 22)
	f:SetPoint("TOPLEFT", 26, y)
	local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	text:SetPoint("LEFT")
	text:SetWidth(126)
	text:SetJustifyH("LEFT")
	text:SetText(label)
	local prev = Button(f, "<", 24)
	prev:SetPoint("LEFT", 130, 0)
	f.value = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	f.value:SetPoint("LEFT", prev, "RIGHT", 4, 0)
	f.value:SetWidth(96)
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
	f:SetSize(700, 720)
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

	-- two columns: target icon + general on the left, raid frames on the right
	local left = CreateFrame("Frame", nil, f)
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(340)
	local right = CreateFrame("Frame", nil, f)
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(360)

	local y = -34

	-- Target icon ---------------------------------------------------------
	y = Header(left, "Target icon", y)
	_, y = Check(left, "Show the target icon", y,
		function() return db().icon.enabled end,
		function(v) db().icon.enabled = v end, "icon")
	_, y = Check(left, "Lock position (unlock to drag it)", y,
		function() return db().icon.locked end,
		function(v) db().icon.locked = v end, "icon")
	_, y = Check(left, "Hide if I don't know Swiftmend", y,
		function() return db().icon.onlyWhenKnown end,
		function(v) db().icon.onlyWhenKnown = v end, "icon")
	_, y = Slider(left, "Icon size", y, 16, 128, 1,
		function() return db().icon.size end,
		function(v) db().icon.size = v end, "icon")
	_, y = Slider(left, "Opacity while Swiftmend is on cooldown", y, 0, 1, 0.05,
		function() return db().icon.cooldownAlpha end,
		function(v) db().icon.cooldownAlpha = v end, "icon", "%.2f")
	_, y = Check(left, "Show border", y,
		function() return db().icon.showBorder end,
		function(v) db().icon.showBorder = v end, "icon")
	_, y = Slider(left, "Border thickness", y, 1, 10, 1,
		function() return db().icon.borderSize end,
		function(v) db().icon.borderSize = v end, "icon")
	_, y = Cycle(left, "Border color", y, ns.BORDER_COLOR_NAMES,
		function() return ns.ColorName(db().icon.borderColor) end,
		function(v) db().icon.borderColor = v end, "icon")
	local resetPos = Button(left, "Reset position", 130)
	resetPos:SetPoint("TOPLEFT", 26, y)
	resetPos:SetScript("OnClick", function() ns.Icon:ResetPosition() end)
	y = y - 34

	-- General -------------------------------------------------------------
	y = Header(left, "General", y)
	_, y = Check(left, "Only count my own Rejuvenation / Regrowth", y,
		function() return db().onlyMine end,
		function(v) db().onlyMine = v end, "filters")

	local rescan = Button(left, "Rescan frames", 130)
	rescan:SetPoint("TOPLEFT", 26, y - 4)
	rescan:SetScript("OnClick", function()
		ns.Frames:ScanNow()
		ns.RefreshAll()
		Config:Sync()
	end)
	local reset = Button(left, "Reset all", 130)
	reset:SetPoint("LEFT", rescan, "RIGHT", 10, 0)
	reset:SetScript("OnClick", function()
		ns.ResetDB()
		ns.Icon:Layout()
		ns.Frames:Relayout()
		Config:Sync()
		ns.Print("settings reset")
	end)

	-- Raid frames ---------------------------------------------------------
	y = Header(right, "Raid frames", -34)
	f.blizz, y = Check(right, "Blizzard raid frames", y,
		function() return db().overlay.blizzard end,
		function(v) db().overlay.blizzard = v end)
	f.buzz, y = Check(right, "Buzzard Frames", y,
		function() return db().overlay.buzzard end,
		function(v) db().overlay.buzzard = v end)
	_, y = Check(right, "Show Swiftmend marker icon", y,
		function() return db().overlay.showIcon end,
		function(v) db().overlay.showIcon = v end, "frames")
	_, y = Check(right, "Show HoT duration spiral on the marker", y,
		function() return db().overlay.showSpiral end,
		function(v) db().overlay.showSpiral = v end, "frames")
	_, y = Check(right, "Show countdown timer on the marker", y,
		function() return db().overlay.showTimer end,
		function(v) db().overlay.showTimer = v end, "frames")
	_, y = Check(right, "Show border around the marker icon", y,
		function() return db().overlay.showIconBorder end,
		function(v) db().overlay.showIconBorder = v end, "frames")
	_, y = Slider(right, "Marker border thickness", y, 1, 10, 1,
		function() return db().overlay.iconBorderSize end,
		function(v) db().overlay.iconBorderSize = v end, "frames")
	_, y = Cycle(right, "Marker border color", y, ns.BORDER_COLOR_NAMES,
		function() return ns.ColorName(db().overlay.iconBorderColor) end,
		function(v) db().overlay.iconBorderColor = v end, "frames")
	_, y = Check(right, "Show border around the raid frame", y,
		function() return db().overlay.showBorder end,
		function(v) db().overlay.showBorder = v end, "frames")
	_, y = Slider(right, "Frame border thickness", y, 1, 10, 1,
		function() return db().overlay.borderSize end,
		function(v) db().overlay.borderSize = v end, "frames")
	_, y = Cycle(right, "Frame border color", y, ns.BORDER_COLOR_NAMES,
		function() return ns.ColorName(db().overlay.borderColor) end,
		function(v) db().overlay.borderColor = v end, "frames")
	_, y = Slider(right, "Marker size", y, 6, 40, 1,
		function() return db().overlay.size end,
		function(v) db().overlay.size = v end, "frames", nil, true)
	_, y = Cycle(right, "Marker anchor", y, POINTS,
		function() return db().overlay.point end,
		function(v) db().overlay.point = v end, "frames")
	_, y = Slider(right, "Marker X offset (left / right)", y, -60, 60, 1,
		function() return db().overlay.offsetX end,
		function(v) db().overlay.offsetX = v end, "frames", nil, true)
	_, y = Slider(right, "Marker Y offset (down / up)", y, -60, 60, 1,
		function() return db().overlay.offsetY end,
		function(v) db().overlay.offsetY = v end, "frames", nil, true)
	local resetMarker = Button(right, "Reset marker position", 160)
	resetMarker:SetPoint("TOPLEFT", 26, y)
	resetMarker:SetScript("OnClick", function()
		local d = ns.defaults.overlay
		db().overlay.point, db().overlay.offsetX, db().overlay.offsetY = d.point, d.offsetX, d.offsetY
		Changed("frames")
		Config:Sync()
	end)
	local previewNote = right:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	previewNote:SetPoint("TOPLEFT", resetMarker, "BOTTOMLEFT", 0, -6)
	previewNote:SetWidth(290)
	previewNote:SetJustifyH("LEFT")
	previewNote:SetText("A preview marker shows on every raid frame while this window is open.")

	f.status = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	f.status:SetPoint("BOTTOMLEFT", 16, 12)
	f.status:SetPoint("BOTTOMRIGHT", -16, 12)
	f.status:SetJustifyH("LEFT")

	f:SetScript("OnShow", function()
		Config:Sync()
		ns.Frames:SetPreview(true)
	end)
	f:SetScript("OnHide", function() ns.Frames:SetPreview(false) end)
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
