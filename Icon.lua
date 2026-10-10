-- Swiftmender Forever: draggable alert icon.
-- Lights up when your friendly target (or anyone in your group) can be
-- Swiftmended. Shows the target's name or the number of candidates, the
-- HoT time left, and Swiftmend's cooldown.

local ADDON, ns = ...
local IsSecret = ns.IsSecret

local Icon = {}
ns.Icon = Icon

local button

local function SavePosition()
	local point, _, relPoint, x, y = button:GetPoint(1)
	ns.db.icon.point = { point, "UIParent", relPoint, x, y }
end

local function ApplyPosition()
	local p = ns.db.icon.point
	button:ClearAllPoints()
	button:SetPoint(p[1] or "CENTER", UIParent, p[3] or "CENTER", p[4] or 0, p[5] or 0)
end

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

	button.glow = button:CreateTexture(nil, "OVERLAY")
	button.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	button.glow:SetBlendMode("ADD")
	button.glow:SetVertexColor(0.3, 1, 0.5)
	button.glow:SetPoint("CENTER")

	button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	button.cooldown:SetAllPoints()
	button.cooldown:SetDrawEdge(false)

	local text = CreateFrame("Frame", nil, button)
	text:SetAllPoints()
	text:SetFrameLevel(button.cooldown:GetFrameLevel() + 2)

	button.count = text:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
	button.count:SetPoint("BOTTOMRIGHT", -2, 2)

	button.timer = text:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	button.timer:SetPoint("TOPLEFT", 3, -3)

	button.label = text:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	button.label:SetPoint("TOP", button, "BOTTOM", 0, -2)

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
end

function Icon:Layout()
	if not button then return end
	local cfg = ns.db.icon
	button:SetSize(cfg.size, cfg.size)
	button.glow:SetSize(cfg.size * 1.75, cfg.size * 1.75)
	button:EnableMouse(not cfg.locked)
	button.hint:SetShown(not cfg.locked)
	ApplyPosition()
	self:Refresh()
end

local function FriendlyTarget()
	local exists = UnitExists("target")
	if IsSecret(exists) or not exists then return false end
	local friend = UnitIsFriend("player", "target")
	return not IsSecret(friend) and friend
end

function Icon:Refresh()
	if not button then return end
	local cfg = ns.db.icon

	if not cfg.enabled or (cfg.onlyWhenKnown and not ns.KnowsSwiftmend() and cfg.locked) then
		button:Hide()
		return
	end
	button:Show()

	local mode = cfg.mode
	local targetCan, targetAura
	if mode ~= "group" and FriendlyTarget() then
		targetCan, targetAura = ns.Evaluate("target")
	end

	local count, firstUnit, firstAura = 0, nil, nil
	if mode ~= "target" then
		for _, unit in ipairs(ns.GroupUnits()) do
			local can, aura = ns.Evaluate(unit)
			if can then
				count = count + 1
				if not firstUnit then firstUnit, firstAura = unit, aura end
			end
		end
	end

	local active, labelUnit, aura
	if targetCan then
		active, labelUnit, aura = true, "target", targetAura
	elseif count > 0 then
		active, labelUnit, aura = true, (count == 1 and firstUnit or nil), firstAura
	end

	if active then
		button:SetAlpha(1)
		button.tex:SetDesaturated(false)
		button.glow:Show()
		button.count:SetText(count > 1 and count or "")
		local name = labelUnit and UnitName(labelUnit)
		button.label:SetText((not IsSecret(name) and name) or (count > 1 and (count .. " targets") or ""))
		local left = ns.Remaining(aura)
		button.timer:SetText(left and string.format("%d", left + 0.5) or "")
	else
		button:SetAlpha(cfg.locked and cfg.inactiveAlpha or 0.6)
		button.tex:SetDesaturated(true)
		button.glow:Hide()
		button.count:SetText("")
		button.label:SetText("")
		button.timer:SetText("")
	end
end

function Icon:RefreshUnit()
	self:Refresh()
end

function Icon:UpdateCooldown()
	if not button then return end
	local id = ns.SPELLS.SWIFTMEND
	if C_Spell and C_Spell.GetSpellCooldown then
		local ok, info = pcall(C_Spell.GetSpellCooldown, id)
		if ok and not IsSecret(info) and info then
			-- the cooldown widget accepts secret numbers, so no comparisons here
			pcall(button.cooldown.SetCooldown, button.cooldown, info.startTime, info.duration)
		end
	elseif GetSpellCooldown then
		local start, duration = GetSpellCooldown(id)
		if start then button.cooldown:SetCooldown(start, duration) end
	end
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
