-- Swiftmender Forever: core state.
-- Tracks which group members carry a Rejuvenation or Regrowth (the two HoTs
-- Swiftmend can consume) and notifies the raid-frame overlays and the icon.

local ADDON, ns = ...
_G.SwiftmenderForever = ns

ns.SPELLS = {
	REJUVENATION = 774,
	REGROWTH = 8936,
	SWIFTMEND = 18562,
}
ns.FALLBACK_ICON = "Interface\\Icons\\INV_Relics_IdolofRejuvenation"

ns.defaults = {
	onlyMine = false,        -- only count HoTs cast by you
	updateInterval = 0.25,   -- seconds between full refreshes
	overlay = {
		blizzard = true,
		buzzard = true,
		size = 14,
		point = "TOPRIGHT",
		offsetX = -2,
		offsetY = -2,
		showIcon = true,
		showBorder = true,
		borderColor = { 0.2, 1.0, 0.4, 0.9 },
		patterns = {
			blizzard = { "^CompactRaid", "^CompactParty" },
			buzzard = { "^Buzzard", "^BF[_%u]" },
		},
	},
	icon = {
		enabled = true,
		locked = false,
		size = 48,
		onlyWhenKnown = true,  -- hide when you don't know Swiftmend
		mode = "both",         -- "target", "group" or "both"
		inactiveAlpha = 0,     -- alpha when nobody can be Swiftmended
		point = { "CENTER", "UIParent", "CENTER", 0, -150 },
	},
}

-- Midnight / Forever "secret values": anything secret can't be compared or
-- tested, so every value read from the aura APIs is checked first.
local issecretvalue = issecretvalue or function() return false end
function ns.IsSecret(v)
	return issecretvalue(v) and true or false
end
local IsSecret = ns.IsSecret

function ns.Print(...)
	print("|cff33ff99Swiftmender|r:", ...)
end

local function CopyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			-- list-like defaults (patterns, colors, points) are only seeded once
			if v[1] == nil then
				CopyDefaults(v, dst[k])
			elseif next(dst[k]) == nil then
				for i, item in ipairs(v) do dst[k][i] = item end
			end
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function ns.ResetDB()
	wipe(SwiftmenderForeverDB)
	CopyDefaults(ns.defaults, SwiftmenderForeverDB)
	ns.db = SwiftmenderForeverDB
end

function ns.SpellName(id)
	if C_Spell and C_Spell.GetSpellName then
		return C_Spell.GetSpellName(id)
	elseif GetSpellInfo then
		return (GetSpellInfo(id))
	end
end

function ns.SpellTexture(id)
	local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
	if tex and not IsSecret(tex) then return tex end
	return ns.FALLBACK_ICON
end

function ns.KnowsSwiftmend()
	local id = ns.SPELLS.SWIFTMEND
	if IsPlayerSpell and IsPlayerSpell(id) then return true end
	if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) then return true end
	-- Forever may use different spell ids per rank; a by-name lookup only
	-- succeeds for spells in your spellbook.
	local name = ns.SpellName(id) or "Swiftmend"
	local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
	return not IsSecret(info) and info ~= nil
end

--------------------------------------------------------------------------
-- Aura scanning
--------------------------------------------------------------------------

local function ValidUnit(unit)
	return type(unit) == "string" and not IsSecret(unit)
		and (unit == "player" or unit == "target" or unit == "focus" or unit == "mouseover"
			or unit:match("^party%d+$") or unit:match("^raid%d+$"))
end
ns.ValidUnit = ValidUnit

-- Spell-name and spell-id lookups stay usable while auras are secret in
-- combat (index-based iteration does not), so only those are used here.
local function FindAura(unit, spellId, filter)
	if C_UnitAuras then
		local name = ns.SpellName(spellId)
		if name and C_UnitAuras.GetAuraDataBySpellName then
			local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name, filter)
			if ok and not IsSecret(aura) and aura ~= nil then return aura end
		end
		if C_UnitAuras.GetUnitAuraBySpellID then
			local ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellId)
			if ok and not IsSecret(aura) and aura ~= nil then
				if not ns.db.onlyMine then return aura end
				local mine = aura.isFromPlayerOrPlayerPet
				if mine == nil or IsSecret(mine) then
					local src = aura.sourceUnit
					mine = not IsSecret(src) and (src == "player" or src == "pet")
				end
				if mine then return aura end
			end
		end
	end
end

-- A secret value can't be tested, so treat it as "unknown" (false).
local function Truthy(v)
	return not IsSecret(v) and v and true or false
end

-- ...or as "probably yes" where a false negative would hide the indicator.
local function Maybe(v)
	return IsSecret(v) or (v and true or false)
end

local cache = {}

-- Returns: canSwiftmend, aura (may be nil), spellKey
function ns.Evaluate(unit)
	if not ValidUnit(unit) then return false end
	local hit = cache[unit]
	if hit then return hit[1], hit[2], hit[3] end

	local can, found, key = false, nil, nil
	if Truthy(UnitExists(unit)) and not Truthy(UnitIsDeadOrGhost(unit)) and Maybe(UnitIsConnected(unit)) then
		local filter = ns.db.onlyMine and "HELPFUL|PLAYER" or "HELPFUL"
		found = FindAura(unit, ns.SPELLS.REJUVENATION, filter)
		key = found and "REJUVENATION"
		if not found then
			found = FindAura(unit, ns.SPELLS.REGROWTH, filter)
			key = found and "REGROWTH"
		end
		can = found ~= nil
	end
	cache[unit] = { can, found, key }
	return can, found, key
end

-- Remaining seconds on the HoT, or nil when unknown/secret.
function ns.Remaining(aura)
	if not aura then return end
	local exp = aura.expirationTime
	if IsSecret(exp) or exp == nil or exp == 0 then return end
	return math.max(0, exp - GetTime())
end

function ns.GroupUnits()
	local units = {}
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
	else
		units[1] = "player"
		for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
	end
	return units
end

--------------------------------------------------------------------------
-- Modules and refresh loop
--------------------------------------------------------------------------

ns.modules = {}
function ns.RegisterModule(mod)
	ns.modules[#ns.modules + 1] = mod
end

local function Call(method, ...)
	for _, mod in ipairs(ns.modules) do
		if mod[method] then mod[method](mod, ...) end
	end
end
ns.Call = Call

function ns.RefreshAll()
	wipe(cache)
	Call("Refresh")
end

function ns.RefreshUnit(unit)
	cache[unit] = nil
	Call("RefreshUnit", unit)
end

local ticker
function ns.StartTicker()
	if ticker then ticker:Cancel() end
	ticker = C_Timer.NewTicker(math.max(0.1, ns.db.updateInterval or 0.25), ns.RefreshAll)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		self:UnregisterEvent("ADDON_LOADED")
		SwiftmenderForeverDB = SwiftmenderForeverDB or {}
		CopyDefaults(ns.defaults, SwiftmenderForeverDB)
		ns.db = SwiftmenderForeverDB

		Call("Init")

		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("GROUP_ROSTER_UPDATE")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:RegisterEvent("SPELLS_CHANGED")
		self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		self:RegisterEvent("UNIT_AURA")
		ns.StartTicker()
	elseif event == "UNIT_AURA" then
		-- the update payload is secret in combat; only the unit token is used
		if ValidUnit(arg1) then ns.RefreshUnit(arg1) end
	elseif event == "PLAYER_TARGET_CHANGED" then
		cache.target = nil
		Call("RefreshUnit", "target")
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		Call("UpdateCooldown")
	else
		-- roster/zone/combat changes: look for new raid frames, then redraw
		Call("Scan", event)
		ns.RefreshAll()
	end
end)
