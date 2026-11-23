local ADDON_NAME, ns = ...

--[[
Core: saved settings, locale, events and the slash command.
Events are only read and handed to the run logic (Logic/Run.lua); Blizzard's loot and roll
frames are never touched.
]]

ns.DEFAULTS = {
	schema = 1,
	debug = false,
	autoOpen = true,        -- banner + recap after the last boss
	sound = 878,            -- success sound kit ID ("Quest complete"), 0 = off
	showGreen = false,      -- list green items (otherwise counted as hidden)
	skin = "blizzard",      -- recap window look: "blizzard" (native) or "recap" (dark & gold)
	tourSeen = false,       -- introduction tour shown once at login (instead of "What's new")
	showWhatsNew = true,    -- "What's new" window after updates (lastSeenVersion: last shown)
	runs = {},              -- finished, completed runs (newest last, max. 20)
	currentRun = nil,       -- the run in progress, saved continuously so /reload loses nothing
	learned = {},           -- [itemID] = "mapID:bossKey", learned from sure loot sources
	learnedNpc = {},        -- [npcID] = "mapID:bossKey", boss NPCs learned (Forever dungeons have no NPC data)
	window = nil,           -- recap window position
	probeActive = false,    -- developer probe (/recap probe) is recording
	probe = {},             -- developer probe log lines
}

-------------------------------------------------------------------------------
-- Locale
-------------------------------------------------------------------------------

ns.clientLocale = ns.NormalizeLocale(GetLocale and GetLocale() or "enUS")

function ns.BuildLocale()
	local base = ns.Locales.enUS or {}
	local own = ns.Locales[ns.clientLocale] or {}
	ns.L = setmetatable({}, {
		__index = function(_, key)
			return own[key] or base[key] or key
		end,
	})
end
ns.BuildLocale()

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------

function ns.InitDB()
	if type(RunRecapDB) ~= "table" then RunRecapDB = {} end
	ns.db = ns.MergeDefaults(RunRecapDB, ns.DEFAULTS)
	ns.db.schema = ns.DEFAULTS.schema
	return ns.db
end

-------------------------------------------------------------------------------
-- Helpers around the WoW API
-------------------------------------------------------------------------------

-- The own name. Forever: UnitName gives the first name, chat lines the full name - the full
-- name is learned from the first own loot line (GUID = UnitGUID("player")).
function ns.MyName()
	if ns.selfFullName then return ns.selfFullName end
	local name = UnitName and UnitName("player")
	return ns.Parse.ShortName(name)
end

function ns.ItemQualityFallback(link)
	local id = ns.Parse.ItemID(link)
	if not id then return nil end
	if C_Item and C_Item.GetItemQualityByID then
		local q = ns.TryCall(C_Item.GetItemQualityByID, id)
		if q then return q end
	end
	if GetItemInfo then return select(3, ns.TryCall(GetItemInfo, link)) end
	return nil
end

-- Vendor price of one piece (copper); 0 if unknown or unsellable.
function ns.SellPrice(link)
	if not link then return 0 end
	local info = { ns.TryCall(GetItemInfo, link) }
	if C_Item and C_Item.GetItemInfo and info[1] == nil then info = { ns.TryCall(C_Item.GetItemInfo, link) } end
	return tonumber(info[11]) or 0
end

-- Repair cost of each equipped item (copper), from the item tooltips - works anywhere, not
-- only at a vendor: { [slot] = { cost, id } }. Slots the client can't read are left out.
local scanTip
local function slotRepairCost(slot)
	if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
		local data = ns.TryCall(C_TooltipInfo.GetInventoryItem, "player", slot)
		if type(data) == "table" and type(data.repairCost) == "number" then return data.repairCost end
	end
	if not CreateFrame then return nil end
	if not scanTip then
		scanTip = CreateFrame("GameTooltip", "RunRecapScanTooltip", nil, "GameTooltipTemplate")
	end
	scanTip:SetOwner(UIParent, "ANCHOR_NONE")
	local ok, _, _, cost = pcall(scanTip.SetInventoryItem, scanTip, "player", slot)
	scanTip:Hide()
	if ok and type(cost) == "number" then return cost end
	return nil
end

function ns.RepairCosts()
	local slots = {}
	for slot = 1, 19 do
		local id = GetInventoryItemID and GetInventoryItemID("player", slot)
		if id then
			local cost = slotRepairCost(slot)
			if cost then slots[slot] = { cost = cost, id = id } end
		end
	end
	return slots
end

function ns.RepairCost()
	local total, known = 0, false
	for _, v in pairs(ns.RepairCosts()) do total, known = total + v.cost, true end
	return known and total or nil
end

local function sampleRepair(reset)
	local run = ns.Run.Current()
	if run then ns.Run.OnRepairSample(run, ns.RepairCosts(), reset) end
end

local function classOfGUID(guid)
	if type(guid) ~= "string" or not GetPlayerInfoByGUID then return nil end
	local _, class = ns.TryCall(GetPlayerInfoByGUID, guid)
	return class
end

local function zoneInfo()
	local info = { inInstance = false }
	if GetInstanceInfo then
		local name, instanceType, _, _, _, _, _, mapID = GetInstanceInfo()
		info.name, info.instanceType, info.mapID = name, instanceType, mapID
		info.inInstance = instanceType ~= nil and instanceType ~= "none"
	end
	info.dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") and true or false
	return info
end

local function updateRoster()
	local run = ns.Run.Current()
	if not run or not UnitName then return end
	local group = {}
	for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
		local name = UnitName(unit)
		if not ns.Run.IsPlaceholder(name) and (not UnitExists or UnitExists(unit)) then
			local class = UnitClass and select(2, UnitClass(unit))
			ns.Run.SetPlayer(run, name, class)
			group[#group + 1] = name
		end
	end
	ns.Run.SetGroup(run, group)
end

local UNITS = { player = true, party1 = true, party2 = true, party3 = true, party4 = true }

local function checkUnit(unit)
	local run = ns.Run.Current()
	if not run or not UNITS[unit] or not UnitName then return end
	local name = UnitName(unit)
	if not name then return end
	local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) and true or false
	if dead and UnitIsFeignDeath and UnitIsFeignDeath(unit) then dead = false end
	ns.Run.OnUnitState(run, name, dead)
end


local function lootWindow()
	local run = ns.Run.Current()
	if not run or not GetNumLootItems then return end
	local slots = {}
	for slot = 1, GetNumLootItems() or 0 do
		local link = GetLootSlotLink and GetLootSlotLink(slot)
		if link and GetLootSourceInfo then
			local guid = ns.TryCall(GetLootSourceInfo, slot)
			local npc = ns.Parse.CreatureGUID(guid)
			-- the name of the dead NPC, if it is the target (for a kill without ENCOUNTER_END)
			local npcName = guid and UnitGUID and UnitGUID("target") == guid and UnitName("target") or nil
			slots[#slots + 1] = { link = link, npc = npc, npcName = npcName }
		end
	end
	ns.Run.OnLootWindow(run, slots)
end

local function chatLoot(msg, sender, guid)
	local run = ns.Run.Current()
	if not run then return end
	local roll = ns.Parse.Roll(msg)
	if roll then
		if roll.kind == "start" then
			ns.Run.OnRollStart(run, roll.historyID, roll.link)
		else
			ns.Run.OnRoll(run, roll, ns.MyName())
		end
		return
	end
	local loot = ns.Parse.Loot(msg)
	if not loot then return end
	local who = loot.self and ns.MyName() or loot.player
	if sender and sender ~= "" then who = ns.Parse.ShortName(sender) end
	if loot.self and sender and sender ~= "" and guid and UnitGUID and guid == UnitGUID("player") then
		ns.selfFullName = ns.Parse.ShortName(sender)
	end
	ns.Run.OnLoot(run, loot, who, classOfGUID(guid))
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
ns.eventFrame = frame

-- Run logic callbacks: keep the window up to date, celebrate a completed dungeon.
ns.Run.onChange = function(run)
	if run then run.lastSeen = ns.Now() end
	if ns.Recap and ns.Recap.OnRunChanged then ns.Recap.OnRunChanged(run) end
end
ns.Run.onComplete = function(run, wing)
	if ns.Banner and ns.Banner.Celebrate then ns.Banner.Celebrate(run, wing) end
end

local handlers = {}

function handlers.ADDON_LOADED(arg1)
	if arg1 ~= ADDON_NAME then return end
	ns.InitDB()
	if ns.Probe then ns.Probe.Resume() end
	frame:UnregisterEvent("ADDON_LOADED")
end

function handlers.PLAYER_ENTERING_WORLD(isLogin, isReload)
	if isLogin or isReload then ns.Run.OnLogin() end
	ns.Run.OnZone(zoneInfo())
	updateRoster()
	sampleRepair()
end

function handlers.ZONE_CHANGED_NEW_AREA()
	ns.Run.OnZone(zoneInfo())
	updateRoster()
	sampleRepair()
end

-- repair costs: durability changes count, gear changes and repairs only move the base
function handlers.UPDATE_INVENTORY_DURABILITY() sampleRepair() end
function handlers.PLAYER_EQUIPMENT_CHANGED() sampleRepair(true) end
function handlers.MERCHANT_CLOSED() sampleRepair() end

function handlers.GROUP_ROSTER_UPDATE() updateRoster() end

function handlers.ENCOUNTER_START(id, name)
	ns.Run.OnEncounterStart(ns.Run.Current(), id, name)
end

function handlers.ENCOUNTER_END(id, name, _, _, success)
	ns.Run.OnEncounterEnd(ns.Run.Current(), id, name, success)
	sampleRepair()
end

function handlers.CHAT_MSG_LOOT(msg, sender, _, _, _, _, _, _, _, _, _, guid)
	chatLoot(msg, sender, guid)
end

function handlers.CHAT_MSG_MONEY(msg)
	ns.Run.OnMoney(ns.Run.Current(), ns.Parse.Money(msg))
end

function handlers.CHAT_MSG_SYSTEM(msg)
	if _G.INSTANCE_RESET_SUCCESS and ns.Parse.Match(_G.INSTANCE_RESET_SUCCESS, msg) then
		ns.Run.OnInstanceReset()
	end
end

function handlers.START_LOOT_ROLL(rollID, _, historyID)
	local link = GetLootRollItemLink and ns.TryCall(GetLootRollItemLink, rollID)
	ns.Run.OnRollStart(ns.Run.Current(), historyID, link)
end

function handlers.LOOT_ROLLS_COMPLETE(historyID)
	ns.Run.OnRollsComplete(ns.Run.Current(), historyID)
end

handlers.LOOT_OPENED = lootWindow

function handlers.PLAYER_DEAD()
	checkUnit("player")
	sampleRepair()
end
-- a dead boss in sight (target, focus, nameplate, mouseover) is a kill, even if no
-- ENCOUNTER_END comes (Elektrokutionator 6000)
local function checkBoss(unit)
	local run = ns.Run.Current()
	if not run or not unit or UNITS[unit] or not UnitGUID or not UnitIsDead then return end
	local npc = ns.Parse.CreatureGUID(UnitGUID(unit))
	if npc and UnitIsDead(unit) then ns.Run.OnBossDead(run, npc, UnitName(unit)) end
end

function handlers.UNIT_HEALTH(unit)
	checkUnit(unit)
	checkBoss(unit)
end
function handlers.PLAYER_TARGET_CHANGED() checkBoss("target") end

function handlers.QUEST_TURNED_IN(_, _, money)
	ns.Run.OnQuestMoney(ns.Run.Current(), money)
end
handlers.UNIT_FLAGS = handlers.UNIT_HEALTH

local function aliveAgain()
	checkUnit("player")
	sampleRepair()
	local info = zoneInfo()
	local run = ns.Run.Current()
	if run and not info.dead and not (info.inInstance and info.mapID == run.mapID) then
		ns.Run.OnAliveOutside()
	end
end
handlers.PLAYER_ALIVE = aliveAgain
handlers.PLAYER_UNGHOST = aliveAgain


function handlers.PLAYER_REGEN_ENABLED()
	if ns.Banner and ns.Banner.OnCombatEnd then ns.Banner.OnCombatEnd() end
end

frame:SetScript("OnEvent", function(_, event, ...)
	local handler = handlers[event]
	if not handler or (event ~= "ADDON_LOADED" and not ns.db) then return end
	local ok, err = pcall(handler, ...)
	if not ok then ns.Debug(event .. " failed: " .. tostring(err)) end
end)

ns.EVENTS = {}
for event in pairs(handlers) do
	ns.EVENTS[#ns.EVENTS + 1] = event
	pcall(frame.RegisterEvent, frame, event)
end

-- Every 30 s: a paused run times out after 30 minutes outside.
if C_Timer and C_Timer.NewTicker then
	C_Timer.NewTicker(30, function()
		if not ns.db then return end
		local run = ns.Run.Current()
		if run and run.state == "active" then run.lastSeen = ns.Now() end
		ns.Run.CheckTimeout()
	end)
end

-------------------------------------------------------------------------------
-- Slash command
-------------------------------------------------------------------------------

SLASH_RUNRECAP1 = "/recap"
SlashCmdList.RUNRECAP = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local L = ns.L
	if not ns.db then ns.InitDB() end
	if ns.Probe and ns.Probe.Slash(msg) then return end
	if msg == "debug" then
		ns.db.debug = not ns.db.debug
		ns.Print(ns.db.debug and L.DEBUG_ON or L.DEBUG_OFF)
		if ns.db.debug then
			local version, build, _, interface = "?", "?", nil, "?"
			if GetBuildInfo then version, build, _, interface = GetBuildInfo() end
			ns.Print(("version %s, client %s.%s, interface %s, locale %s"):format(ns.VERSION,
				tostring(version), tostring(build), tostring(interface), ns.clientLocale))
			local run = ns.Run.Current()
			if run then
				ns.Print(("run: %s (%s), %s, %d kills, %d items"):format(tostring(run.name), tostring(run.mapID),
					run.state, #run.kills, #run.items))
			end
		end
	elseif msg == "help" or msg == "?" then
		ns.Print(L.SLASH_HELP)
	elseif msg == "options" or msg == "config" or msg == "opt" then
		if ns.Options then ns.Options.Open() end
	elseif msg == "demo" then
		if ns.Demo then ns.Demo.Show() end
	elseif msg == "tour" then
		if ns.Tour then ns.Tour.Show() end
	elseif msg == "news" then
		if ns.WhatsNew then ns.WhatsNew.ShowPage(ns.VERSION) end
	elseif msg == "" then
		local run = ns.Run.Latest()
		if run and ns.Recap then
			ns.Recap.Toggle(run)
		else
			ns.Print(L.NO_RECAP_YET)
		end
	else
		ns.Print(L.SLASH_HELP)
	end
end
