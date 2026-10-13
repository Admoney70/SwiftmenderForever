-- Swiftmender Forever: "won't overheal" gate for the raid-frame markers and
-- the target icon's glow. The missing-health gate near the end is the main
-- path; the percent curve below is the fallback.
--
-- Swiftmend consumes the HoT and heals for (roughly) a full Rejuvenation,
-- so a marker is only useful when the unit is missing at least that much.
-- In combat other units' health is secret, so Lua can't compare it. What
-- Blizzard does allow is evaluating a curve against the secret health
-- *percent* (UnitHealthPercent(unit, predicted, curve)) and handing the
-- result straight to SetAlpha. So we turn the heal into a percent threshold
-- per unit -- 1 - heal / maxHealth -- using max health cached whenever it is
-- readable (out of combat), and build a step curve: alpha 1 at or below the
-- threshold, 0 above it.

local ADDON, ns = ...
local IsSecret = ns.IsSecret

local Overheal = {}
ns.Overheal = Overheal

local maxHealth = {}   -- [unit] = last readable max health
local curves = {}      -- [unit] = { curve = curve, threshold = t }
local estimate         -- cached heal estimate from the Rejuvenation tooltip

local function Readable(v)
	return not IsSecret(v) and type(v) == "number" and v > 0
end

-- Highest-rank Rejuvenation the player knows, by exact spell id.
local function RejuvenationID()
	local name = ns.SpellName(ns.SPELLS.REJUVENATION)
	local info = name and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
	local id = info and not IsSecret(info) and info.spellID
	if type(id) == "number" and not IsSecret(id) then return id end
	return ns.SPELLS.REJUVENATION
end

-- First number in the tooltip ("Heals the target for 888 over 12 sec.").
local function ParseHeal(text)
	if type(text) ~= "string" or IsSecret(text) then return end
	local num = text:match("(%d[%d,]*)")
	if not num then return end
	return tonumber((num:gsub(",", "")))
end

-- Re-read the heal estimate (out of combat; tooltips include spell power).
function Overheal.UpdateEstimate()
	local id = RejuvenationID()
	local text
	if C_Spell and C_Spell.GetSpellDescription then
		text = C_Spell.GetSpellDescription(id)
	elseif GetSpellDescription then
		text = GetSpellDescription(id)
	end
	local heal = ParseHeal(text)
	if heal and heal > 0 then estimate = heal end
end

-- Heal amount the gate assumes, or nil when unknown.
function Overheal.HealAmount()
	local cfg = ns.db.overlay
	if (cfg.overhealAmount or 0) > 0 then return cfg.overhealAmount end
	if not estimate then return end
	return math.floor(estimate * (cfg.overhealScale or 100) / 100 + 0.5)
end

function Overheal.Estimate()
	return estimate
end

-- Remember max health while it's readable.
function Overheal.UpdateUnit(unit)
	local m = UnitHealthMax(unit)
	if Readable(m) then maxHealth[unit] = m end
end

local function CurveFor(unit, threshold)
	local entry = curves[unit]
	if entry and entry.threshold == threshold then return entry.curve end
	local curve = C_CurveUtil.CreateCurve()
	curve:SetType(Enum.LuaCurveType.Step)
	curve:AddPoint(0, 1)
	-- the heal fits exactly at the threshold, so keep that point visible
	curve:AddPoint(math.min(1, threshold + 0.0001), 0)
	curves[unit] = { curve = curve, threshold = threshold }
	return curve
end

local function Threshold(unit)
	local heal, max = Overheal.HealAmount(), maxHealth[unit]
	if not heal or not max then return end
	local t = 1 - heal / max
	if t < 0 then t = 0 end
	return math.floor(t * 1000 + 0.5) / 1000 -- reuse curves for tiny changes
end

function Overheal.Supported()
	return UnitHealthPercent ~= nil and C_CurveUtil and C_CurveUtil.CreateCurve ~= nil
		and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step ~= nil
end

-- 1 when the unit is missing at least the heal, else 0. May be a secret
-- number (fine for SetAlpha). `unknown` when the heal or max health isn't
-- known (or the API is missing).
function Overheal.FitsAlpha(unit, unknown)
	if not Overheal.Supported() then return unknown end
	local t = Threshold(unit)
	if not t then return unknown end
	return UnitHealthPercent(unit, ns.db.overlay.overhealPredicted and true or false, CurveFor(unit, t))
end

-- Alpha for the unit's marker gate: 1 when the option is off or unknown.
function Overheal.Alpha(unit)
	if not ns.db.overlay.noOverheal then return 1 end
	return Overheal.FitsAlpha(unit, 1)
end

-- Missing health from the game (secret in combat), or nil without the API.
local function Missing(unit)
	if not UnitHealthMissing then return end
	local ok, v = pcall(UnitHealthMissing, unit, ns.db.overlay.overhealPredicted and true or false)
	if ok and (IsSecret(v) or type(v) == "number") then return v end
end

-- Plain yes/no from readable health (nil = unknown, e.g. secret).
function Overheal.Fits(unit)
	local heal = Overheal.HealAmount()
	local missing = heal and Missing(unit)
	if missing ~= nil and not IsSecret(missing) then return missing >= heal end
	local hp, max = UnitHealth(unit), UnitHealthMax(unit)
	if not heal or not Readable(max) or IsSecret(hp) or type(hp) ~= "number" then return nil end
	if ns.db.overlay.overhealPredicted and UnitGetIncomingHeals then
		local inc = UnitGetIncomingHeals(unit)
		if not IsSecret(inc) and type(inc) == "number" then hp = hp + inc end
	end
	return max - hp >= heal
end

-- Marker gate for the out-of-combat fallback path.
function Overheal.Allows(unit)
	if not ns.db.overlay.noOverheal then return true end
	return Overheal.Fits(unit) ~= false
end

-- "target" is a different unit after a target swap: drop its cached max
-- health, re-read it, or borrow it from the group unit it matches.
function Overheal.TargetChanged()
	maxHealth.target = nil
	Overheal.UpdateUnit("target")
	if maxHealth.target then return end
	for _, unit in ipairs(ns.GroupUnits()) do
		local same = UnitIsUnit("target", unit)
		if not IsSecret(same) and same and maxHealth[unit] then
			maxHealth.target = maxHealth[unit]
			return
		end
	end
	local me = UnitIsUnit("target", "player")
	if not IsSecret(me) and me then maxHealth.target = maxHealth.player end
end

--------------------------------------------------------------------------
-- missing-health gate
--------------------------------------------------------------------------
-- UnitHealthMissing (what Blizzard's raid frames show as "Health Missing")
-- needs no max health, so it also works for units we never saw out of
-- combat. Its value is secret in combat, but StatusBars accept secret
-- values: a hidden bar with the range [heal - 1, heal] is completely full
-- when the unit is missing at least the heal and empty otherwise. A
-- clipping frame anchored to the bar's fill is then either the whole area
-- or nothing, so whatever is inside it only shows when Swiftmend fits.
-- Without UnitHealthMissing the gate falls back to the percent curve above.

local GATE_TEXTURE = "Interface\\Buttons\\WHITE8X8"

-- `margin` extends the area beyond `parent`, for things drawn outside it.
function Overheal.CreateGate(parent, margin)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetPoint("TOPLEFT", parent, "TOPLEFT", -margin, margin)
	bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", margin, -margin)
	bar:SetStatusBarTexture(GATE_TEXTURE)
	bar:SetStatusBarColor(0, 0, 0, 0)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	local clip = CreateFrame("Frame", nil, parent)
	clip:SetClipsChildren(true)
	local fill = bar:GetStatusBarTexture()
	clip:SetPoint("TOPLEFT", fill, "TOPLEFT")
	clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
	return { bar = bar, clip = clip }
end

local function Open(gate)
	gate.bar:SetMinMaxValues(0, 1)
	gate.bar:SetValue(1)
end

-- Opens the gate only while the unit is missing at least the heal. When
-- `active` is false the gate is simply open; `unknown` (1 or 0) is the
-- alpha used when the heal or the unit's health can't be worked out.
function Overheal.UpdateGate(gate, unit, active, unknown)
	if not active then
		Open(gate)
		gate.clip:SetAlpha(1)
		return
	end
	local heal = Overheal.HealAmount()
	local missing = heal and Missing(unit)
	if missing ~= nil then
		gate.bar:SetMinMaxValues(math.max(0, heal - 1), heal)
		gate.bar:SetValue(missing)
		gate.clip:SetAlpha(1)
		return
	end
	Open(gate)
	local alpha = Overheal.FitsAlpha(unit, unknown)
	if not IsSecret(alpha) and type(alpha) ~= "number" then alpha = unknown end
	gate.clip:SetAlpha(alpha)
end

-- Debug report for /sm health: what the game exposes for a unit.
function Overheal.Report(unit)
	local function show(v)
		if IsSecret(v) then return "|cffff8800secret|r" end
		return tostring(v)
	end
	local function call(f, ...)
		if not f then return "|cff888888no API|r" end
		local ok, v = pcall(f, ...)
		if not ok then return "|cffff3333error|r" end
		return show(v)
	end
	local predicted = ns.db.overlay.overhealPredicted and true or false
	ns.Print(string.format("%s (%s): exists %s, friendly %s", unit, show(UnitName(unit)),
		call(UnitExists, unit), call(UnitCanAssist, "player", unit)))
	print(string.format("  UnitHealth %s, UnitHealthMax %s, cached max %s",
		call(UnitHealth, unit), call(UnitHealthMax, unit), tostring(maxHealth[unit])))
	print(string.format("  UnitHealthMissing %s (predicted: %s), UnitHealthPercent %s",
		call(UnitHealthMissing, unit), call(UnitHealthMissing, unit, true), call(UnitHealthPercent, unit)))
	print(string.format("  UnitGetIncomingHeals %s, in combat %s", call(UnitGetIncomingHeals, unit),
		tostring(InCombatLockdown())))
	print(string.format("  heal: tooltip estimate %s, used %s (fixed %s, %d%%), counts incoming %s",
		tostring(estimate), tostring(Overheal.HealAmount()), tostring(ns.db.overlay.overhealAmount),
		ns.db.overlay.overhealScale or 100, tostring(predicted)))
	local path = (UnitHealthMissing and Overheal.HealAmount()) and "missing health"
		or Overheal.Supported() and "health percent curve (needs cached max)" or "none"
	local fits = Overheal.Fits(unit)
	print(string.format("  gate uses: %s; fits now: %s; raid filter %s, icon glow %s", path,
		fits == nil and "unknown (secret)" or tostring(fits),
		tostring(ns.db.overlay.noOverheal), tostring(ns.db.icon.overhealGlow)))
end

-- Out-of-combat upkeep (throttled by the caller).
function Overheal.Refresh()
	Overheal.UpdateEstimate()
	for _, unit in ipairs(ns.GroupUnits()) do Overheal.UpdateUnit(unit) end
	Overheal.UpdateUnit("player")
	Overheal.UpdateUnit("target")
end
