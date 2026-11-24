local _, ns = ...

--[[
Probe (developer tool, hidden): finds out what WoW Forever actually delivers before the real
run tracking is built. Nothing here touches Blizzard frames; it only listens to events and
reads loot slot data while the loot window is open.

  /recap probe        start/stop recording (survives /reload; stored in RunRecapDB.probe)
  /recap probe clear  delete the recording
  /recap sounds       play the success sound candidates one after another (3 s apart)
  /recap sound <id>   play one sound kit ID
  /recap shot         show the last run as a copy in the client language (gallery screenshots)

Messages are English on purpose (developer output, like BGF's "/bgf check").
]]

local Probe = {}
ns.Probe = Probe

local MAX_ENTRIES = 3000

-- Candidates for the success sound. Not every ID exists in every client: PlaySound reports it.
Probe.SOUNDS = {
	{ id = 888,   name = "Level up" },
	{ id = 878,   name = "Quest complete" },
	{ id = 17316, name = "Dungeon finder rewards (later expansions, may be missing)" },
	{ id = 12891, name = "Achievement (later expansions, may be missing)" },
	{ id = 8455,  name = "Battleground victory (Alliance)" },
	{ id = 8454,  name = "Battleground victory (Horde)" },
	{ id = 8959,  name = "Raid warning" },
	{ id = 8960,  name = "Ready check" },
}

-- Events recorded while probing. Printed ones also go to chat right away.
local EVENTS = {
	"ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
	"CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "LOOT_ROLLS_COMPLETE",
	"LOOT_OPENED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "COMBAT_LOG_EVENT_UNFILTERED",
}
local PRINTED = { ENCOUNTER_START = true, ENCOUNTER_END = true, BOSS_KILL = true, LOOT_OPENED = true,
	PLAYER_ENTERING_WORLD = true, START_LOOT_ROLL = true }

-- Global strings for loot and rolls; the probe records which exist and what they say.
Probe.GLOBAL_STRINGS = {
	"LOOT_ITEM", "LOOT_ITEM_SELF", "LOOT_ITEM_MULTIPLE", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF",
	"LOOT_ROLL_NEED", "LOOT_ROLL_NEED_SELF", "LOOT_ROLL_GREED", "LOOT_ROLL_GREED_SELF",
	"LOOT_ROLL_PASSED", "LOOT_ROLL_PASSED_SELF", "LOOT_ROLL_PASSED_AUTO", "LOOT_ROLL_ALL_PASSED",
	"LOOT_ROLL_ROLLED_NEED", "LOOT_ROLL_ROLLED_GREED", "LOOT_ROLL_WON", "LOOT_ROLL_YOU_WON",
	"LOOT_ROLL_WON_NO_SPAM_NEED", "LOOT_ROLL_WON_NO_SPAM_GREED", "LOOT_ROLL_DISENCHANT",
	"LOOT_MONEY_SPLIT", "YOU_LOOT_MONEY", "LOOT_MONEY",
}

local function db() return ns.db end

local function stringify(...)
	local out = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		out[#out + 1] = type(v) == "string" and ("%q"):format(v) or tostring(v)
	end
	return table.concat(out, ", ")
end

-- Short form of a GUID: "Creature-0-1-2-3-4-5" -> "Creature npc=4".
function Probe.ShortGUID(guid)
	if type(guid) ~= "string" then return tostring(guid) end
	local kind, _, _, _, _, npcID = strsplit("-", guid)
	if kind == "Creature" or kind == "Vehicle" or kind == "GameObject" then
		return ("%s npc=%s"):format(kind, tostring(npcID))
	end
	return kind or guid
end

local function instanceText()
	if not GetInstanceInfo then return "GetInstanceInfo missing" end
	local name, instType, difficultyID, difficultyName, maxPlayers, _, _, instanceID = GetInstanceInfo()
	return stringify(name, instType, difficultyID, difficultyName, maxPlayers, instanceID)
end

function Probe.Add(event, text)
	local d = db()
	if not d then return end
	d.probe = d.probe or {}
	local log = d.probe
	log[#log + 1] = ("%s | %.1f | %s | %s"):format(date and date("%H:%M:%S") or "?", GetTime and GetTime() or 0,
		event, text or "")
	while #log > MAX_ENTRIES do table.remove(log, 1) end
	if PRINTED[event] then ns.Print("|cff7fbfffprobe|r " .. event .. " " .. (text or "")) end
end

local frame = CreateFrame("Frame")
Probe.frame = frame

-- Loot window open: per slot the item and where it came from (GetLootSourceInfo).
local function recordLootWindow()
	local n = GetNumLootItems and GetNumLootItems() or 0
	Probe.Add("LOOT_OPENED", ("%d slots, GetLootSourceInfo %s"):format(n,
		GetLootSourceInfo and "exists" or "MISSING"))
	for slot = 1, n do
		local link = GetLootSlotLink and GetLootSlotLink(slot)
		local sources = {}
		if GetLootSourceInfo then
			local info = { pcall(GetLootSourceInfo, slot) }
			if info[1] then
				for i = 2, #info, 2 do
					sources[#sources + 1] = Probe.ShortGUID(info[i]) .. " x" .. tostring(info[i + 1])
				end
			else
				sources[1] = "error: " .. tostring(info[2])
			end
		end
		Probe.Add("LOOT_SLOT", ("%d %s <- %s"):format(slot, tostring(link or "(money/no link)"),
			#sources > 0 and table.concat(sources, "; ") or "no source"))
	end
end

-- Combat log: only deaths (bosses, players, everything) to see how deaths and kills look.
local function recordCombatLog()
	if not CombatLogGetCurrentEventInfo then return end
	local _, sub, _, _, _, _, _, destGUID, destName, destFlags = CombatLogGetCurrentEventInfo()
	if sub == "UNIT_DIED" or sub == "UNIT_DESTROYED" or sub == "PARTY_KILL" then
		Probe.Add("CLEU", stringify(sub, destName, Probe.ShortGUID(destGUID), destFlags))
	end
end

frame:SetScript("OnEvent", function(_, event, ...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		recordCombatLog()
	elseif event == "LOOT_OPENED" then
		recordLootWindow()
	elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "ENCOUNTER_END"
		or event == "BOSS_KILL" then
		Probe.Add(event, stringify(...) .. " | instance: " .. instanceText())
	else
		Probe.Add(event, stringify(...))
	end
end)

-- Facts recorded once per start: client, API availability, global strings.
function Probe.Snapshot()
	local version, build, _, interface = "?", "?", nil, "?"
	if GetBuildInfo then version, build, _, interface = GetBuildInfo() end
	Probe.Add("START", ("client %s.%s interface %s, Run Recap %s, locale %s"):format(tostring(version),
		tostring(build), tostring(interface), ns.VERSION, ns.clientLocale))
	local apis = {}
	for _, name in ipairs({ "GetInstanceInfo", "GetLootSourceInfo", "GetLootSlotLink", "CombatLogGetCurrentEventInfo",
		"GetLootRollItemLink", "C_LootHistory", "C_Loot", "GetCoinTextureString", "PlaySound", "PlaySoundFile" }) do
		apis[#apis + 1] = name .. "=" .. (_G[name] ~= nil and "yes" or "NO")
	end
	Probe.Add("API", table.concat(apis, " "))
	for _, key in ipairs(Probe.GLOBAL_STRINGS) do
		local value = _G[key]
		Probe.Add("GLOBALSTRING", key .. " = " .. (type(value) == "string" and ("%q"):format(value) or "MISSING"))
	end
	Probe.Add("INSTANCE", instanceText())
end

function Probe.Register()
	for _, event in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, event) end
end

function Probe.Unregister()
	for _, event in ipairs(EVENTS) do pcall(frame.UnregisterEvent, frame, event) end
end

function Probe.Start()
	ns.db.probeActive = true
	Probe.Register()
	Probe.Snapshot()
	ns.Print("probe ON - recording to RunRecapDB.probe. Run a dungeon, then /recap probe to stop.")
end

function Probe.Stop()
	ns.db.probeActive = false
	Probe.Unregister()
	Probe.Add("STOP", "")
	ns.Print(("probe OFF - %d lines recorded. Log out or /reload so the file gets written."):format(#(ns.db.probe or {})))
end

-- Called after the saved variables are loaded: resume recording after /reload.
function Probe.Resume()
	if ns.db and ns.db.probeActive then
		Probe.Register()
		Probe.Add("RESUME", instanceText())
	end
end

function Probe.PlaySound(id, label)
	local willPlay
	if PlaySound then
		local ok, result = pcall(PlaySound, id, "Master")
		willPlay = ok and result
	end
	ns.Print(("sound %d (%s): %s"):format(id, label or "?", willPlay and "plays" or "NOT available"))
	Probe.Add("SOUND", ("%d %s"):format(id, willPlay and "plays" or "missing"))
	return willPlay
end

function Probe.PlayAll()
	local list = Probe.SOUNDS
	local function step(i)
		local s = list[i]
		if not s then return end
		Probe.PlaySound(s.id, ("%d/%d %s"):format(i, #list, s.name))
		if C_Timer and C_Timer.After then C_Timer.After(3, function() step(i + 1) end) end
	end
	step(1)
end

-- Slash sub-commands; returns true when handled.
--[[
Screenshot copy (CurseForge gallery, Felix 24.11.2026): the last run as a copy whose dungeon,
boss and item names follow the client language - so a run recorded with a German client can
be shown in English. Players, rolls, times, money stay real. Boss names: there is no API for
them, so the English names of the dungeons Felix plays are listed here. Nothing is saved.
]]
local BOSS_NAMES_EN = {
	-- Razorfen Kraul
	Jargba = "Death Speaker Jargba", Aggem = "Aggem Thorncurse", Ramtusk = "Overlord Ramtusk",
	Roogug = "Roogug", Agathelos = "Agathelos the Raging", Charlga = "Charlga Razorflank",
}

local function copy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = copy(v) end
	return c
end

function Probe.Shot()
	local run = ns.Run.Latest()
	if not run then
		ns.Print("shot: no finished run yet")
		return
	end
	local shot = copy(run)
	shot.demo, shot.id = true, -1
	local english = (GetLocale and GetLocale() or "enUS"):sub(1, 2) == "en"
	local dungeon = ns.DUNGEONS and ns.DUNGEONS[run.mapID]
	if english and dungeon and dungeon.name then shot.name = dungeon.name end
	for _, kill in ipairs(shot.kills or {}) do
		if english and BOSS_NAMES_EN[kill.key] then kill.name = BOSS_NAMES_EN[kill.key] end
	end
	local missing = 0
	for _, item in ipairs(shot.items or {}) do
		local itemString = item.link and item.link:match("|H(item:[^|]+)|h")
		local link
		if GetItemInfo then
			-- the full item string keeps random suffixes ("... of the Falcon"); Forever may not
			-- resolve its link format, then the plain item ID
			if itemString then link = select(2, GetItemInfo(itemString)) end
			if not link and item.itemID then link = select(2, GetItemInfo(item.itemID)) end
		end
		if link then
			item.link = link
		else
			missing = missing + 1
			if C_Item and C_Item.RequestLoadItemDataByID and item.itemID then
				C_Item.RequestLoadItemDataByID(item.itemID)
			end
		end
	end
	if missing > 0 then
		ns.Print(("shot: %d of %d item names not loaded yet - run /recap shot again in a moment"):format(missing,
			#(shot.items or {})))
	else
		ns.Print(("shot: all %d item names in the client language"):format(#(shot.items or {})))
	end
	ns.Banner.PlaySound()
	ns.Banner.Show(shot, function(r)
		if InCombatLockdown and InCombatLockdown() then return end
		ns.Recap.Show(r)
	end)
	return shot
end

function Probe.Slash(msg)
	if msg == "shot" then
		Probe.Shot()
		return true
	end
	if msg == "probe" then
		if ns.db.probeActive then Probe.Stop() else Probe.Start() end
		return true
	elseif msg == "probe clear" then
		ns.db.probe = {}
		ns.Print("probe log cleared")
		return true
	elseif msg == "sounds" then
		Probe.PlayAll()
		return true
	end
	local id = msg:match("^sound%s+(%d+)$")
	if id then
		Probe.PlaySound(tonumber(id), "manual")
		return true
	end
	return false
end
