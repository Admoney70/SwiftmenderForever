-- Swiftmender Forever: "won't overheal" gate for the raid-frame markers.
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

-- Alpha for the unit's marker gate. May be a secret number (fine for
-- SetAlpha). 1 when the option is off or the heal/max health is unknown.
function Overheal.Alpha(unit)
	if not ns.db.overlay.noOverheal or not Overheal.Supported() then return 1 end
	local t = Threshold(unit)
	if not t then return 1 end
	return UnitHealthPercent(unit, ns.db.overlay.overhealPredicted and true or false, CurveFor(unit, t))
end

-- Plain yes/no for the out-of-combat fallback path (nil = unknown).
function Overheal.Allows(unit)
	if not ns.db.overlay.noOverheal then return true end
	local heal = Overheal.HealAmount()
	local hp, max = UnitHealth(unit), UnitHealthMax(unit)
	if not heal or not Readable(max) or IsSecret(hp) or type(hp) ~= "number" then return true end
	if ns.db.overlay.overhealPredicted and UnitGetIncomingHeals then
		local inc = UnitGetIncomingHeals(unit)
		if not IsSecret(inc) and type(inc) == "number" then hp = hp + inc end
	end
	return max - hp >= heal
end

-- Out-of-combat upkeep (throttled by the caller).
function Overheal.Refresh()
	Overheal.UpdateEstimate()
	for _, unit in ipairs(ns.GroupUnits()) do Overheal.UpdateUnit(unit) end
	Overheal.UpdateUnit("player")
end
