-- Swiftmender Forever: combat-safe HoT detection.
-- While auras are secret (combat, encounters, M+, PvP) addons can't read
-- them, so every aura lookup comes back nil or secret. Blizzard's native
-- AuraContainer still can: we give it one aura slot filtered to the
-- Rejuvenation/Regrowth spell ids, and the game itself shows that slot's
-- button only while such a HoT is on the unit. Everything we draw (marker,
-- border, spiral, countdown) is a child of that button, so it appears and
-- disappears with it without the addon ever seeing the secret data.
--
-- Rules from Blizzard's 12.1 AuraContainer contract:
--  * Blizzard_AuraContainer must be loaded out of combat.
--  * initializeFrame runs every time the native button is (re)created, so
--    decorating must be idempotent; no pcall probing inside it.
--  * The button and its children can be write-protected while auras are
--    secret, so restyling waits until Native.Mutable() is true again.

local ADDON, ns = ...

local Native = {}
ns.Native = Native

local SLOT = "swiftmender_hot"
local CONTAINER_ADDON = "Blizzard_AuraContainer"

-- Rejuvenation and Regrowth across every rank (Classic through Wrath ids),
-- plus whatever ids are seen on live auras (ns.db.learnedSpellIDs).
local BASE_IDS = {
	774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299, 26981, 26982, 48440, 48441,
	8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858, 26980, 48442, 48443,
}

local loaded

function Native.Load()
	if loaded ~= nil then return loaded end
	local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
	if isLoaded and isLoaded(CONTAINER_ADDON) then
		loaded = true
	elseif load and not InCombatLockdown() then
		load(CONTAINER_ADDON)
		loaded = isLoaded and isLoaded(CONTAINER_ADDON) and true or false
	else
		return false -- try again out of combat
	end
	if loaded then
		-- the template must exist and expose the slot API
		local ok, probe = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
		loaded = ok and probe and type(probe.AddAuraSlot) == "function"
			and type(probe.SetUnit) == "function" and true or false
		if ok and probe then probe:Hide() end
	end
	return loaded
end

function Native.Available()
	return loaded == true and not ns.db.forceLegacy
end

-- True when native buttons may be restyled.
function Native.Mutable()
	if InCombatLockdown() then return false end
	if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
		return false
	end
	return true
end

function Native.SpellIDs()
	local ids = {}
	for _, id in ipairs(BASE_IDS) do ids[id] = true end
	for id in pairs(ns.db.learnedSpellIDs or {}) do ids[id] = true end
	-- the highest rank the player knows (exact id the buff will carry)
	for _, base in ipairs({ ns.SPELLS.REJUVENATION, ns.SPELLS.REGROWTH }) do
		local name = ns.SpellName(base)
		local info = name and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
		local id = info and not ns.IsSecret(info) and info.spellID
		if type(id) == "number" and not ns.IsSecret(id) then ids[id] = true end
	end
	return ids
end

local function FilterString()
	return ns.db.onlyMine and "HELPFUL|PLAYER" or "HELPFUL"
end

local sensors = {}  -- [container] = true

-- Creates a native sensor on `parent` watching `unit`. `decorate(button)`
-- is called whenever Blizzard (re)creates the slot's button.
function Native.CreateSensor(parent, unit, decorate)
	if not Native.Available() then return end
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
	if not ok or not container then return end
	container:SetAllPoints(parent)
	container.smUnit = unit
	container:SetUnit(unit)
	container:SetEnabled(true)
	container:AddAuraSlot(SLOT, FilterString(), {
		maxFrameCount = 1,
		candidateFilters = { includeSpellIDs = Native.SpellIDs() },
		initializeFrame = function(button)
			container.smButton = button
			decorate(button)
		end,
	})
	container:Show()
	sensors[container] = true
	return container
end

function Native.SetUnit(container, unit)
	if not container or container.smUnit == unit then return end
	container.smUnit = unit
	container:SetUnit(unit)
	Native.Update(container)
end

-- Re-read the unit's auras (target swaps keep the same unit token).
function Native.Update(container)
	if container and container.UpdateAllAuras then container:UpdateAllAuras() end
end

local pendingFilters
-- Push filter changes (only-mine, newly learned ids) to every sensor.
function Native.RefreshFilters()
	if not Native.Mutable() then
		pendingFilters = true
		return
	end
	pendingFilters = nil
	local filter, ids = FilterString(), { includeSpellIDs = Native.SpellIDs() }
	for container in pairs(sensors) do
		container:SetAuraSlotFilterString(SLOT, filter)
		container:SetAuraSlotCandidateFilters(SLOT, ids)
		Native.Update(container)
	end
end

function Native.Flush()
	if pendingFilters then Native.RefreshFilters() end
end

-- Remember the exact id of a HoT seen out of combat, so a server that uses
-- its own spell ids is still matched in combat.
function Native.Learn(spellId)
	if type(spellId) ~= "number" or ns.IsSecret(spellId) then return end
	ns.db.learnedSpellIDs = ns.db.learnedSpellIDs or {}
	if ns.db.learnedSpellIDs[spellId] then return end
	for _, id in ipairs(BASE_IDS) do
		if id == spellId then return end
	end
	ns.db.learnedSpellIDs[spellId] = true
	Native.RefreshFilters()
end

-- Countdown text options: whole seconds, rendered C-side from the secret
-- duration.
local timerOptions
function Native.TimerOptions()
	if timerOptions == nil then
		timerOptions = {}
		local su = C_StringUtil
		local rounding = Enum and Enum.NumericRuleFormatRounding
		if su and su.CreateNumericRuleFormatter and rounding then
			local f = su.CreateNumericRuleFormatter()
			if f and f.SetBreakpoints then
				f:SetBreakpoints({
					{ threshold = 0, step = 1, rounding = rounding.Up or rounding.Nearest, format = "%d" },
				})
				timerOptions = { textFormatter = f, formatter = f }
			end
		end
	end
	return timerOptions
end
