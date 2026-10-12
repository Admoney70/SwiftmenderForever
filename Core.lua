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
	forceLegacy = false,     -- skip the native (combat-safe) aura sensors
	overlay = {
		blizzard = true,
		buzzard = true,
		size = 14,
		point = "TOPRIGHT",
		offsetX = -2,
		offsetY = -2,
		showIcon = true,
		showSpiral = true,       -- HoT duration spiral on the marker icon
		showTimer = true,        -- countdown text for the last 10 seconds
		showBorder = true,      -- border around the whole raid frame
		borderSize = 2,
		borderColor = "Green",
		noOverheal = false,     -- only show markers when Swiftmend won't overheal
		overhealScale = 100,    -- % of the estimated heal (Rejuvenation tooltip)
		overhealAmount = 0,     -- fixed heal amount instead of the estimate (0 = auto)
		overhealPredicted = true, -- count incoming heals as already landed
		fadeOnCooldown = true,  -- fade markers while Swiftmend is on cooldown
		cooldownAlpha = 0.35,
		showIconBorder = true,  -- border around the marker icon
		iconBorderSize = 1,
		iconBorderColor = "Black",
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
		showInactive = true,   -- greyed icon when the target can't be Swiftmended
		cooldownAlpha = 0.35,  -- alpha when they can but Swiftmend is on cooldown
		showCooldown = true,   -- Swiftmend cooldown spiral
		showTimer = true,      -- HoT time-left number on the icon
		tintRange = true,      -- red when the target is out of range
		tintMana = true,       -- blue when you lack the mana
		desatUnusable = true,  -- grey when Swiftmend can't be used
		showBorder = true,
		borderSize = 2,
		borderColor = "Green",
		trackSelf = true,      -- follow yourself with no target or an enemy target
		overhealGlow = true,   -- glow when Swiftmend won't overheal the target
		glowColor = "Gold",
		glowStyle = "Glow",    -- Glow, Proc (ability activation) or Pixel
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

ns.BORDER_COLORS = {
	Green = { 0.2, 1.0, 0.4, 0.9 },
	Black = { 0, 0, 0, 1 },
	White = { 1, 1, 1, 1 },
	Gold = { 1, 0.82, 0, 1 },
	Red = { 1, 0.2, 0.2, 1 },
	Blue = { 0.3, 0.6, 1, 1 },
}
ns.BORDER_COLOR_NAMES = { "Green", "Black", "White", "Gold", "Red", "Blue" }

-- Saved colours are names; older saves hold an RGBA table (the old green).
function ns.ColorName(v)
	return type(v) == "string" and ns.BORDER_COLORS[v] and v or "Green"
end

-- Lays out four edge textures as a border around `anchor`; `outside` puts
-- the border just outside the anchor instead of on its inner edge.
function ns.LayoutEdges(edges, anchor, size, color, shown, outside)
	local o = outside and size or 0
	local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
	top:ClearAllPoints()
	top:SetPoint("TOPLEFT", anchor, "TOPLEFT", -o, o)
	top:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", o, o)
	top:SetHeight(size)
	bottom:ClearAllPoints()
	bottom:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -o, -o)
	bottom:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", o, -o)
	bottom:SetHeight(size)
	left:ClearAllPoints()
	left:SetPoint("TOPLEFT", anchor, "TOPLEFT", -o, o)
	left:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -o, -o)
	left:SetWidth(size)
	right:ClearAllPoints()
	right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", o, o)
	right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", o, -o)
	right:SetWidth(size)
	local r, g, b, a = unpack(ns.BORDER_COLORS[ns.ColorName(color)])
	for i = 1, 4 do
		edges[i]:SetVertexColor(r, g, b, a)
		edges[i]:SetShown(shown)
	end
end

function ns.CreateEdges(parent, sublevel)
	local edges = {}
	for i = 1, 4 do
		local t = parent:CreateTexture(nil, "OVERLAY", nil, sublevel or 6)
		t:SetColorTexture(1, 1, 1, 1)
		edges[i] = t
	end
	return edges
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
		if found and ns.Native then ns.Native.Learn(found.spellId) end
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

-- With native sensors nothing else reads auras, so every couple of seconds
-- out of combat we scan the group once to learn the exact HoT spell ids this
-- server uses (see Native.Learn).
local lastLearn = 0
local function LearnPass()
	if GetTime() - lastLearn < 2 then return end
	lastLearn = GetTime()
	for _, unit in ipairs(ns.GroupUnits()) do ns.Evaluate(unit) end
	ns.Evaluate("target")
end

-- Max health and the Rejuvenation heal estimate for the overheal gate.
local lastOverheal = 0
local function OverhealPass()
	if GetTime() - lastOverheal < 1 then return end
	lastOverheal = GetTime()
	ns.Overheal.Refresh()
end

function ns.RefreshAll()
	wipe(cache)
	if ns.Native.Mutable() then
		ns.Native.Flush()
		Call("Flush")
		if ns.Native.Available() then LearnPass() end
		OverhealPass()
	end
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
		ns.Native.Load()

		Call("Init")

		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("GROUP_ROSTER_UPDATE")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:RegisterEvent("SPELLS_CHANGED")
		self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		self:RegisterEvent("UNIT_AURA")
		self:RegisterEvent("UNIT_HEALTH")
		self:RegisterEvent("UNIT_MAXHEALTH")
		ns.StartTicker()
	elseif event == "UNIT_AURA" then
		-- the update payload is secret in combat; only the unit token is used
		if ValidUnit(arg1) then ns.RefreshUnit(arg1) end
	elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		-- only the overheal gate (raid markers, target icon glow) uses health
		if event == "UNIT_MAXHEALTH" and ValidUnit(arg1) then ns.Overheal.UpdateUnit(arg1) end
		if ns.db.overlay.noOverheal and ValidUnit(arg1) then
			ns.Frames:RefreshUnit(arg1)
		end
		if (arg1 == "target" or arg1 == "player") and ns.db.icon.overhealGlow then
			ns.Icon:Refresh()
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		cache.target = nil
		ns.Overheal.TargetChanged()
		Call("TargetChanged")
		Call("RefreshUnit", "target")
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		Call("UpdateCooldown")
	else
		-- roster/zone/combat changes: look for new raid frames, then redraw
		Call("Scan", event)
		ns.RefreshAll()
	end
end)
