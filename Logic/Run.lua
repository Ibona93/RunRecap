local _, ns = ...

--[[
The run: one visit to a dungeon instance, from entering it until it ends.

  * starts when entering a known dungeon (ns.DUNGEONS), saved in RunRecapDB.currentRun
  * leaving as a ghost: keeps running; leaving alive: paused (pause time is not counted)
  * ends when another instance is entered, the instance is reset (message while outside), or
    after 30 minutes outside; entering the same dungeon again after a completed run (left alive)
    starts a new run. (Until 23.11.2026 a different instance copy was detected from creature
    GUIDs - unreliable in Forever, it restarted a run in the middle of Dalaran.)
  * completed when a wing is complete (Logic/Dungeons.lua); the run keeps recording after
    that, because the end boss's loot is rolled for afterwards
  * finished runs that were completed go to RunRecapDB.runs (last 20); others are dropped

Loot -> source (no shipped loot tables):
  1. own loot window: GetLootSourceInfo -> NPC -> boss (from the data or learned), otherwise
     trash if the dungeon's boss NPC IDs are known; unknown NPCs in dungeons without NPC data
     (the Forever dungeons) give no answer - the rules below decide, and a roll right after a
     kill teaches "this NPC is that boss" (RunRecapDB.learnedNpc)                (sure)
  2. rolling: started within ROLL_WINDOW s after a boss kill -> that boss,
     otherwise trash                                                            (sure)
  3. learned from 1/2 earlier: item -> boss (RunRecapDB.learned)               (sure)
  4. the rest: within GUESS_WINDOW s after a boss kill -> "probably" that boss,
     otherwise trash
Only green or better items are kept (white/grey loot is never shown).

All times are seconds of run time (pauses outside left out). Pure logic apart from
ns.Now() and the callbacks - covered by tests/run.lua.
]]

local Run = {}
ns.Run = Run

Run.ROLL_WINDOW = 10      -- roll start this soon after a kill = that boss's loot
Run.GUESS_WINDOW = 90     -- loot of others this soon after a kill = probably that boss
Run.LOOT_WINDOW_KEEP = 120 -- how long items from the own loot window remember their source
Run.CLAIM_WINDOW = 300    -- "X receives loot" this long after a won roll belongs to that roll
Run.PAUSE_LIMIT = 30 * 60 -- outside alive this long ends the run
Run.HISTORY = 20          -- finished runs kept
Run.MIN_QUALITY = 2       -- green

-- Callbacks, set by Core/UI: Run.onChange(run), Run.onComplete(run, wing)
local function changed(run)
	if Run.onChange then Run.onChange(run) end
end

function ns.Now()
	return time and time() or os.time()
end

local function db() return ns.db end

function Run.Current()
	local d = db()
	return d and d.currentRun
end

-------------------------------------------------------------------------------
-- Run time
-------------------------------------------------------------------------------

function Run.Elapsed(run, now)
	if not run then return 0 end
	now = now or ns.Now()
	local until_ = run.pausedAt or now
	return math.max(0, until_ - run.startedAt - (run.pausedTotal or 0))
end

-------------------------------------------------------------------------------
-- Start / pause / resume / end
-------------------------------------------------------------------------------

function Run.New(mapID, name, now)
	now = now or ns.Now()
	local d = db()
	d.nextRunID = (d.nextRunID or 0) + 1
	local run = {
		id = d.nextRunID, mapID = mapID, name = name, startedAt = now, date = now,
		pausedTotal = 0, state = "active",
		kills = {},          -- in kill order: { key, name, encounterID, wing, at, fight, final, opt }
		killed = {},         -- [bossKey] = kill index
		wings = {},          -- [wingKey] = true (touched by a kill)
		completedWings = {}, -- [wingKey] = run time of completion
		wipes = 0, bossWipes = {}, bossDeaths = {},
		items = {},          -- { link, itemID, quality, count, looter, source (kill index | "trash"), sure, rolls, ... }
		deaths = {}, deadNow = {}, players = {},
		money = 0,          -- own share of looted gold (copper)
		vendor = 0,         -- vendor value of own loot, without items won with need (copper)
		repair = 0,         -- own repair costs that came up during the run (copper)
	}
	d.currentRun = run
	ns.Debug("run started: " .. tostring(name) .. " (" .. tostring(mapID) .. ")")
	changed(run)
	return run
end

function Run.Pause(run, now)
	if not run or run.state == "paused" then return end
	run.state = "paused"
	run.pausedAt = now or ns.Now()
	ns.Debug("run paused")
end

function Run.Resume(run, now)
	if not run or run.state ~= "paused" then return end
	now = now or ns.Now()
	run.pausedTotal = (run.pausedTotal or 0) + math.max(0, now - (run.pausedAt or now))
	run.pausedAt = nil
	run.state = "active"
	ns.Debug("run resumed")
end

-- Ends the current run: completed runs go to the history, others are dropped.
function Run.End(reason)
	local d = db()
	local run = d and d.currentRun
	if not run then return end
	d.currentRun = nil
	run.endReason = reason
	run.loot = nil
	if run.completed then
		if run.pausedAt then run.pausedAt = nil end
		run.state = "finished"
		d.runs[#d.runs + 1] = run
		while #d.runs > Run.HISTORY do table.remove(d.runs, 1) end
	end
	ns.Debug("run ended (" .. tostring(reason) .. ")" .. (run.completed and ", kept" or ", dropped"))
	changed(run)
	return run
end

-- The run the recap window shows: the current one once completed, else the last finished one.
function Run.Latest()
	local d = db()
	if not d then return nil end
	if d.currentRun and d.currentRun.completed then return d.currentRun end
	return d.runs[#d.runs]
end

--[[
Zone change. info = { inInstance, instanceType, mapID, name, dead }
Decides start / resume / pause / end.
]]
function Run.OnZone(info, now)
	now = now or ns.Now()
	local run = Run.Current()
	local dungeon = info.inInstance and info.instanceType == "party" and ns.DUNGEONS[info.mapID]
	if run then
		if info.inInstance and info.mapID == run.mapID then
			if run.completed and run.state == "paused" then
				-- back in the same dungeon after a completed run (left alive): a new run
				Run.End("again")
				return Run.New(info.mapID, info.name or (dungeon and dungeon.name), now)
			end
			Run.Resume(run, now)
			return run
		end
		if info.inInstance then
			-- another instance: the old run is over
			Run.End("other instance")
			run = nil
		elseif run.state == "active" and not info.dead then
			Run.Pause(run, now)
		end
	end
	if not run and dungeon then
		return Run.New(info.mapID, info.name or dungeon.name, now)
	end
	return run
end

--[[
Login or /reload. A run that was active when the game was left counts as paused since it was
last seen: after 30 minutes it is over.
]]
function Run.OnLogin(now)
	now = now or ns.Now()
	local run = Run.Current()
	if not run then return end
	if run.state == "active" then
		if run.lastSeen and now - run.lastSeen >= Run.PAUSE_LIMIT then
			Run.End("timeout")
			return
		end
	end
	Run.CheckTimeout(now)
end

-- Called regularly and on events: ends a run that has been paused too long.
function Run.CheckTimeout(now)
	now = now or ns.Now()
	local run = Run.Current()
	if run and run.state == "paused" and run.pausedAt and now - run.pausedAt >= Run.PAUSE_LIMIT then
		Run.End("timeout")
		return true
	end
	return false
end

-- A ghost outside who is alive again (resurrected at the spirit healer): now it is a pause.
function Run.OnAliveOutside(now)
	local run = Run.Current()
	if run and run.state == "active" then Run.Pause(run, now) end
end

-- "<instance> has been reset": a paused run is over.
function Run.OnInstanceReset()
	local run = Run.Current()
	if run and run.state == "paused" then Run.End("reset") end
end


-------------------------------------------------------------------------------
-- Players and deaths
-------------------------------------------------------------------------------

--[[
Names: in Forever the unit functions give the first name ("Anna"), chat lines the full name
("Anna Kramer"). A first name and exactly one full name starting with it are one player: the
full name wins, everything recorded under the first name moves over (run.alias first -> full).
]]
local function merge(run, short, full)
	run.alias = run.alias or {}
	run.alias[short] = full
	if run.players[short] ~= nil then
		if not run.players[full] then run.players[full] = run.players[short] end
		run.players[short] = nil
	end
	if run.deaths[short] then
		run.deaths[full] = (run.deaths[full] or 0) + run.deaths[short]
		run.deaths[short] = nil
	end
	if run.deadNow[short] then run.deadNow[full], run.deadNow[short] = true, nil end
	for _, list in pairs(run.bossDeaths) do
		for i, n in ipairs(list) do if n == short then list[i] = full end end
	end
	for _, item in ipairs(run.items) do
		if item.looter == short then item.looter = full end
		local r = item.rolls and item.rolls[short]
		if r then
			local target = item.rolls[full] or {}
			target.choice = target.choice or r.choice
			target.value = target.value or r.value
			item.rolls[full] = target
			item.rolls[short] = nil
		end
	end
end

local function reconcile(run)
	for short in pairs(run.players) do
		if not short:find(" ", 1, true) then
			local match, count = nil, 0
			for full in pairs(run.players) do
				if full:sub(1, #short + 1) == short .. " " then match, count = full, count + 1 end
			end
			if count == 1 then merge(run, short, match) end
		end
	end
end

-- The name a player is recorded under (full name once known).
function Run.Canon(run, name)
	if not name then return nil end
	name = ns.Parse.ShortName(name)
	return run and run.alias and run.alias[name] or name
end

-- "Unbekannt"/"Unknown": the client doesn't know the name yet (UNKNOWNOBJECT). A name with
-- link characters (| [ ]) is a cut item link, never a player (Kloster 25.11.2026).
function Run.IsPlaceholder(name)
	return name == nil or name == "" or name == UNKNOWNOBJECT or name == UNKNOWN or ns.Parse.IsBadName(name)
end

--[[
Repair of runs recorded before 1.0.1: roll lines with an item name containing the format's own
words ("[Mantel von Doan]") stored names like "Doan]|h|r von Flutscho Butterfinger". A bad name
that ends with a clean player name of the run moves to that player (rolls: value only if the
player has none; deaths added; looter replaced); otherwise it is removed. Language-independent:
only a suffix compare. Returns true if anything was changed.
]]
function Run.RepairNames(run)
	if type(run) ~= "table" then return false end
	local bad, good = ns.Parse.IsBadName, {}
	for name in pairs(run.players or {}) do
		if type(name) == "string" and not bad(name) then good[#good + 1] = name end
	end
	-- longest name first: "Anna Kramer" wins over "Kramer"
	table.sort(good, function(a, b) return #a > #b end)
	local memo, fixed = {}, false
	local function target(name)
		if memo[name] == nil then
			memo[name] = false
			for _, g in ipairs(good) do
				if #name > #g and name:sub(-#g) == g then memo[name] = g break end
			end
		end
		return memo[name] or nil
	end
	local function collect(t)
		local list = {}
		for k in pairs(t) do if bad(k) then list[#list + 1] = k end end
		return list
	end
	if type(run.players) == "table" then
		for _, name in ipairs(collect(run.players)) do
			local to = target(name)
			if to and not run.players[to] then run.players[to] = run.players[name] end
			run.players[name] = nil
			fixed = true
		end
	end
	if type(run.deaths) == "table" then
		for _, name in ipairs(collect(run.deaths)) do
			local to = target(name)
			if to then run.deaths[to] = (run.deaths[to] or 0) + (tonumber(run.deaths[name]) or 0) end
			run.deaths[name] = nil
			fixed = true
		end
	end
	if type(run.bossDeaths) == "table" then
		for _, list in pairs(run.bossDeaths) do
			if type(list) == "table" then
				for i = #list, 1, -1 do
					if bad(list[i]) then
						local to = target(list[i])
						if to then list[i] = to else table.remove(list, i) end
						fixed = true
					end
				end
			end
		end
	end
	for _, item in ipairs(type(run.items) == "table" and run.items or {}) do
		if bad(item.looter) then
			item.looter = target(item.looter)
			fixed = true
		end
		if type(item.rolls) == "table" then
			for _, name in ipairs(collect(item.rolls)) do
				local r, to = item.rolls[name], target(name)
				if to and type(r) == "table" then
					local entry = item.rolls[to] or {}
					entry.choice = entry.choice or r.choice
					if entry.value == nil then entry.value = r.value end
					item.rolls[to] = entry
				end
				item.rolls[name] = nil
				fixed = true
			end
		end
	end
	if type(run.alias) == "table" then
		for short, full in pairs(run.alias) do
			if bad(short) then
				run.alias[short] = nil
				fixed = true
			elseif bad(full) then
				run.alias[short] = target(full)
				fixed = true
			end
		end
	end
	if type(run.deadNow) == "table" then
		for _, name in ipairs(collect(run.deadNow)) do run.deadNow[name] = nil end
	end
	return fixed
end

function Run.SetPlayer(run, name, class)
	if not run or Run.IsPlaceholder(name) then return end
	name = Run.Canon(run, name)
	if class or run.players[name] == nil then run.players[name] = class or false end
	reconcile(run)
end

function Run.OnDeath(run, name)
	if not run or not name or run.state ~= "active" then return end
	name = Run.Canon(run, name)
	run.deaths[name] = (run.deaths[name] or 0) + 1
	if run.players[name] == nil then run.players[name] = false end
	local enc = run.encounter
	if enc then
		local list = run.bossDeaths[enc.key] or {}
		run.bossDeaths[enc.key] = list
		list[#list + 1] = name
	end
	changed(run)
end

-- Unit state check (UNIT_HEALTH / UNIT_FLAGS / PLAYER_DEAD): counts a death once per dying.
function Run.OnUnitState(run, name, dead)
	if not run or Run.IsPlaceholder(name) then return end
	name = Run.Canon(run, name)
	if dead and not run.deadNow[name] then
		run.deadNow[name] = true
		Run.OnDeath(run, name)
		Run.CheckGroupWipe(run)
	elseif not dead and run.deadNow[name] then
		run.deadNow[name] = nil
		if not next(run.deadNow) then run.groupWiped = nil end
	end
end

-- Current group (names as UnitName gives them), set by Core on roster changes.
function Run.SetGroup(run, names)
	if not run then return end
	run.group = {}
	for _, name in ipairs(names or {}) do
		if not Run.IsPlaceholder(name) then run.group[name] = true end
	end
end

--[[
Wipe outside a boss fight (trash), Felix 23.11.2026: the whole group is dead, or all but one
(the paladin in his bubble, the hunter playing dead) in a group of four or more. Counted once
until everyone is alive again. Boss wipes come from ENCOUNTER_END.
]]
function Run.CheckGroupWipe(run)
	if not run or run.state ~= "active" or run.encounter or run.groupWiped or not run.group then return end
	local size, dead = 0, 0
	for name in pairs(run.group) do
		size = size + 1
		-- first names from the unit functions; the full name may be known by now
		if run.deadNow[Run.Canon(run, name)] then dead = dead + 1 end
	end
	if size == 0 then return end
	if dead == size or (size >= 4 and dead >= size - 1) then
		run.groupWiped = true
		run.wipes = (run.wipes or 0) + 1
		changed(run)
	end
end

-------------------------------------------------------------------------------
-- Bosses
-------------------------------------------------------------------------------

local function bossFor(run, encounterID, name)
	local mapID, _, wing, boss = ns.Dungeons.FindEncounter(encounterID)
	if boss and mapID == run.mapID then return boss, wing end
	-- unknown encounter: still listed (optional, no wing), loot can attach to it
	return { key = "enc" .. tostring(encounterID), opt = true, unknown = true, name = name }, nil
end

function Run.OnEncounterStart(run, encounterID, name, now)
	if not run or run.state ~= "active" then return end
	local boss = bossFor(run, encounterID, name)
	run.encounter = { id = encounterID, key = boss.key, name = name, at = Run.Elapsed(run, now) }
end

-- Progress over all touched wings: killed / total required bosses.
function Run.BossProgress(run)
	local done, total = 0, 0
	local dungeon = ns.DUNGEONS[run.mapID]
	if not dungeon then return #run.kills, #run.kills end
	local touched = next(run.wings) ~= nil
	for _, wing in ipairs(dungeon.wings) do
		if run.wings[wing.key] or (not touched and #dungeon.wings == 1) then
			local _, d, t = ns.Dungeons.WingProgress(wing, run.killed)
			done, total = done + d, total + t
		end
	end
	return done, total
end

local function addKill(run, boss, wing, name, now, extra)
	local at = Run.Elapsed(run, now)
	local kill = {
		key = boss.key, name = name, wing = wing and wing.key,
		at = at, final = boss.final, opt = boss.opt, rare = boss.rare, time = now,
	}
	for k, v in pairs(extra or {}) do kill[k] = v end
	run.kills[#run.kills + 1] = kill
	run.killed[boss.key] = #run.kills
	run.lastKill = #run.kills
	if wing then
		run.wings[wing.key] = true
		local complete = ns.Dungeons.WingProgress(wing, run.killed)
		if complete and not run.completedWings[wing.key] then
			run.completedWings[wing.key] = at
			run.completed = true
			run.completedAt = at
			-- dungeons without a fixed end boss: the last required boss is marked
			if not boss.opt then kill.last = true end
			changed(run)
			if Run.onComplete then Run.onComplete(run, wing) end
			return kill
		end
	end
	changed(run)
	return kill
end

function Run.OnEncounterEnd(run, encounterID, name, success, now)
	if not run or run.state ~= "active" then return end
	now = now or ns.Now()
	local boss, wing = bossFor(run, encounterID, name)
	local at = Run.Elapsed(run, now)
	local enc = run.encounter
	local fight = (enc and enc.id == encounterID) and math.max(0, at - enc.at) or nil
	run.encounter = nil
	if success ~= 1 and success ~= true then
		run.groupWiped = next(run.deadNow) ~= nil or nil
		run.wipes = run.wipes + 1
		run.bossWipes[boss.key] = (run.bossWipes[boss.key] or 0) + 1
		changed(run)
		return
	end
	local index = run.killed[boss.key]
	if index then
		-- already known from the dead boss itself: the encounter adds the fight time
		local kill = run.kills[index]
		if kill.fromNpc then
			kill.fight, kill.encounterID, kill.fromNpc = kill.fight or fight, encounterID, nil
			if name then kill.name = name end
			changed(run)
		end
		return
	end
	return addKill(run, boss, wing, name, now, { encounterID = encounterID, fight = fight })
end

-- A known boss of this dungeon is dead (its corpse, its loot window) but no ENCOUNTER_END
-- came - it happens (Elektrokutionator 6000, Gnomeregan, 23.11.2026). Counts as the kill.
function Run.OnBossDead(run, npc, name, now)
	if not run or run.state ~= "active" or not npc then return end
	local mapID, _, wing, boss = ns.Dungeons.FindNpc(npc)
	if not boss or mapID ~= run.mapID or run.killed[boss.key] then return end
	-- a fight is running: ENCOUNTER_END follows and brings the fight time
	if run.encounter and run.encounter.key == boss.key then return end
	return addKill(run, boss, wing, name or boss.key, now or ns.Now(), { fromNpc = true })
end

-------------------------------------------------------------------------------
-- Loot
-------------------------------------------------------------------------------

local function learnedKey(run, kill) return run.mapID .. ":" .. kill.key end

local function learn(run, item)
	local d = db()
	if not d or type(item.source) ~= "number" or not item.sure or not item.itemID then return end
	local kill = run.kills[item.source]
	if kill and not kill.unknown then
		d.learned = d.learned or {}
		d.learned[item.itemID] = learnedKey(run, kill)
	end
end

-- Source from timing: the last kill, if it was at most `window` seconds ago.
local function recentKill(run, now, window)
	local index = run.lastKill
	local kill = index and run.kills[index]
	if kill and kill.time and now - kill.time <= window then return index end
	return nil
end

-- Boss key of an NPC in this dungeon: from the data, else learned (RunRecapDB.learnedNpc).
local function npcBoss(run, npc)
	local mapID, _, _, boss = ns.Dungeons.FindNpc(npc)
	if boss and mapID == run.mapID then return boss.key end
	local d = db()
	local key = d and d.learnedNpc and d.learnedNpc[npc]
	if key then
		local m, bossKey = key:match("^(%d+):(.+)$")
		if tonumber(m) == run.mapID then return bossKey end
	end
	return nil
end

-- Does the data know the boss NPC IDs of this dungeon? (Not for the Forever dungeons.)
local function hasNpcData(run)
	local dungeon = ns.DUNGEONS[run.mapID]
	if not dungeon then return false end
	for _, wing in ipairs(dungeon.wings) do
		for _, boss in ipairs(wing.bosses) do
			if boss.npc and #boss.npc > 0 then return true end
		end
	end
	return false
end

--[[
Source from the own loot window (GetLootSourceInfo), remembered per item ID: a killed boss
(kill index), "trash" (NPC is no boss and the dungeon's boss NPCs are known), or nil (no loot
window, or an unknown NPC in a dungeon without NPC data - then the other rules decide).
]]
local function lootWindowSource(run, itemID, now)
	local entry = run.loot and run.loot[itemID]
	if not entry or now - entry.time > Run.LOOT_WINDOW_KEEP then return nil end
	local key = npcBoss(run, entry.npc)
	if key then return run.killed[key] or "trash" end
	if hasNpcData(run) then return "trash" end
	return nil
end

-- A roll right after a kill and the loot window of NPC `npc` for that item: NPC = that boss.
local function learnNpc(run, item, npc)
	local d = db()
	local kill = type(item.source) == "number" and run.kills[item.source]
	if not d or not kill or kill.unknown or not npc then return end
	d.learnedNpc = d.learnedNpc or {}
	d.learnedNpc[npc] = learnedKey(run, kill)
end

local function learnedSource(run, itemID)
	local d = db()
	local key = d and d.learned and d.learned[itemID]
	if not key then return nil end
	local mapID, bossKey = key:match("^(%d+):(.+)$")
	if tonumber(mapID) ~= run.mapID then return nil end
	return run.killed[bossKey]
end

local function newItem(run, link, now)
	local quality = ns.Parse.ItemQuality(link)
	if not quality and ns.ItemQualityFallback then quality = ns.ItemQualityFallback(link) end
	if (quality or 0) < Run.MIN_QUALITY then return nil end
	local item = {
		link = link, itemID = ns.Parse.ItemID(link), quality = quality, count = 1,
		at = Run.Elapsed(run, now), time = now, rolls = {},
	}
	run.items[#run.items + 1] = item
	return item
end

-- The own loot window opened: slots = { { link, npcID }, ... }
function Run.OnLootWindow(run, slots, now)
	if not run or run.state ~= "active" then return end
	now = now or ns.Now()
	run.loot = run.loot or {}
	-- loot of a known boss without a recorded kill: the kill is missing, not the boss
	for _, slot in ipairs(slots) do
		if slot.npc then Run.OnBossDead(run, slot.npc, slot.npcName, now) end
	end
	for _, slot in ipairs(slots) do
		local itemID = ns.Parse.ItemID(slot.link)
		if itemID and slot.npc then
			run.loot[itemID] = { npc = slot.npc, time = now }
			-- items rolled for right now: the loot window is the better source
			for _, item in ipairs(run.items) do
				if item.itemID == itemID and item.historyID and not item.fromWindow and now - item.time <= 60 then
					local source = lootWindowSource(run, itemID, now)
					if source then
						item.source, item.sure, item.fromWindow = source, true, true
						learn(run, item)
					elseif type(item.source) == "number" then
						-- unknown NPC, rolled right after a kill: that NPC is the boss
						learnNpc(run, item, slot.npc)
						item.fromWindow = true
					end
					changed(run)
					break
				end
			end
		end
	end
	-- forget old entries
	for id, entry in pairs(run.loot) do
		if now - entry.time > Run.LOOT_WINDOW_KEEP then run.loot[id] = nil end
	end
end

local function dropFor(run, historyID, link, now)
	for _, item in ipairs(run.items) do
		if item.historyID == historyID then return item end
	end
	if not link then return nil end
	local item = newItem(run, link, now)
	if not item then return nil end
	item.historyID = historyID
	item.rolling = true
	local fromWindow = lootWindowSource(run, item.itemID, now)
	if fromWindow then
		item.source, item.fromWindow = fromWindow, true
	else
		item.source = recentKill(run, now, Run.ROLL_WINDOW) or "trash"
		local entry = run.loot and run.loot[item.itemID]
		if entry and type(item.source) == "number" then learnNpc(run, item, entry.npc) end
	end
	item.sure = true
	learn(run, item)
	return item
end

-- START_LOOT_ROLL (or the announcement line): an item is being rolled for.
function Run.OnRollStart(run, historyID, link, now)
	if not run or run.state ~= "active" or not historyID then return end
	now = now or ns.Now()
	local item = dropFor(run, historyID, link, now)
	if item then changed(run) end
	return item
end

-- Parsed roll line (ns.Parse.Roll). me = the player's own name.
function Run.OnRoll(run, r, me, now)
	if not run or run.state ~= "active" then return end
	now = now or ns.Now()
	local item = dropFor(run, r.historyID, r.link, now)
	if not item then return end
	local who = r.self and me or r.player
	if Run.IsPlaceholder(who) then who = nil end
	if who then
		Run.SetPlayer(run, who)
		who = Run.Canon(run, who)
	end
	if r.kind == "choice" and who then
		local entry = item.rolls[who] or {}
		entry.choice = r.roll
		item.rolls[who] = entry
	elseif r.kind == "roll" and who then
		local entry = item.rolls[who] or {}
		entry.choice, entry.value = r.roll, r.value
		item.rolls[who] = entry
	elseif r.kind == "won" then
		item.looter = who
		item.rolling = nil
		if r.value and who then
			local entry = item.rolls[who] or {}
			entry.choice, entry.value = entry.choice or r.roll, entry.value or r.value
			item.rolls[who] = entry
		end
	elseif r.kind == "allpassed" then
		item.rolling = nil
		item.allPassed = true
	end
	changed(run)
	return item
end

function Run.OnRollsComplete(run, historyID)
	if not run then return end
	for _, item in ipairs(run.items) do
		if item.historyID == historyID and item.rolling then
			item.rolling = nil
			changed(run)
		end
	end
end

--[[
"X receives loot: [item]". l = ns.Parse.Loot result, who = looter name, class = class file
(from the GUID) or nil. Belongs to a finished roll for the same item if there is one;
otherwise a new item with a source by the rules above.
]]
-- Vendor value of own loot (Felix, 22.11.2026): everything looted, grey and white included,
-- but not items won with a need roll. ns.SellPrice(link) -> copper per piece (Core).
local function addVendorValue(run, l, rolled, me)
	if not l.self or not ns.SellPrice then return end
	local mine = rolled and rolled.rolls and me and rolled.rolls[me]
	if mine and mine.choice == "need" then return end
	local price = ns.SellPrice(l.link) or 0
	if price > 0 then run.vendor = (run.vendor or 0) + price * (l.count or 1) end
end

function Run.OnLoot(run, l, who, class, now)
	if not run or run.state ~= "active" or not l or not who or ns.Parse.IsBadName(who) then return end
	now = now or ns.Now()
	Run.SetPlayer(run, who, class)
	who = Run.Canon(run, who)
	local itemID = ns.Parse.ItemID(l.link)
	for _, item in ipairs(run.items) do
		if item.historyID and not item.claimed and item.itemID == itemID and now - item.time <= Run.CLAIM_WINDOW
			and (item.looter == who or item.allPassed or (item.rolling and item.looter == nil)) then
			item.claimed = true
			item.looter = who
			item.rolling = nil
			addVendorValue(run, l, item, who)
			changed(run)
			return item
		end
	end
	addVendorValue(run, l, nil, who)
	local item = newItem(run, l.link, now)
	if not item then return nil end
	item.count = l.count or 1
	item.looter = who
	item.direct = true
	local fromWindow = l.self and lootWindowSource(run, itemID, now)
	if fromWindow then
		item.source, item.sure = fromWindow, true
		learn(run, item)
	else
		local learned = learnedSource(run, itemID)
		if learned then
			item.source, item.sure, item.learned = learned, true, true
		else
			local recent = recentKill(run, now, Run.GUESS_WINDOW)
			item.source = recent or "trash"
			item.sure = false
		end
	end
	changed(run)
	return item
end

--[[
Repair costs: `cost` = current repair cost of the equipped gear (Core reads it from the item
tooltips). Only increases while the run is active count; a lower value (repaired, e.g. on a
hearthstone trip to a vendor) just becomes the new base. resetBase: gear was changed, take the
value as the new base without counting.
]]
--[[
Repair costs per equipment slot: `slots` = { [slot] = { cost = copper, id = itemID } } for the
slots the client could read. Outside a vendor costs only go up, so a slot counts only what
goes above its highest value so far - a slot that reads low for a moment (tooltip not ready)
can't be counted twice (Gnomeregan 23.11.2026: 40s instead of 20s). Another item in the slot,
`reset` (gear change, vendor closed) or a run that isn't active only move the base.
]]
function Run.OnRepairSample(run, slots, reset)
	if not run or type(slots) ~= "table" then return end
	run.repairBase = run.repairBase or {}
	local base, active, added = run.repairBase, run.state == "active" and not reset, 0
	for slot, v in pairs(slots) do
		local b = base[slot]
		if not active or not b or b.id ~= v.id then
			base[slot] = { cost = v.cost, id = v.id }
		elseif v.cost > b.cost then
			added = added + v.cost - b.cost
			b.cost = v.cost
		end
	end
	if added > 0 then
		run.repair = (run.repair or 0) + added
		changed(run)
	end
end

-- Gold of a quest handed in inside the instance (not the reward items), Felix 23.11.2026
function Run.OnQuestMoney(run, copper)
	if type(copper) ~= "number" or copper <= 0 then return end
	Run.OnMoney(run, copper)
end

function Run.OnMoney(run, copper)
	if not run or run.state ~= "active" or not copper then return end
	run.money = (run.money or 0) + copper
	changed(run)
end

-------------------------------------------------------------------------------
-- Summary for the recap window
-------------------------------------------------------------------------------

local function sortedRolls(item)
	local list = {}
	for name, r in pairs(item.rolls or {}) do
		list[#list + 1] = { name = name, choice = r.choice, value = r.value }
	end
	local rank = { need = 1, greed = 2, disenchant = 3, transmog = 4, pass = 5 }
	table.sort(list, function(a, b)
		local ra, rb = rank[a.choice] or 6, rank[b.choice] or 6
		if ra ~= rb then return ra < rb end
		if (a.value or -1) ~= (b.value or -1) then return (a.value or -1) > (b.value or -1) end
		return a.name < b.name
	end)
	return list
end
Run.SortedRolls = sortedRolls

--[[
Builds what the window shows. showGreen: green items listed (otherwise counted as hidden).
Returns {
  bosses = { { kill, sure = {items}, unsure = {items}, itemCount } ... },
  trash = { items }, hidden = n, duration, done, total, wipes, money,
  deaths = { { name, n } ... } (most first), noDeaths = { names },
  fastest = kill, mostLoot = { name, n }, mostDeaths = { name, n }
}
]]
function Run.Summary(run, showGreen)
	local s = { bosses = {}, trash = {}, hidden = 0 }
	local byKill = {}
	for i, kill in ipairs(run.kills) do
		local entry = { kill = kill, index = i, sure = {}, unsure = {}, itemCount = 0 }
		s.bosses[i] = entry
		byKill[i] = entry
	end
	local lootCount = {}
	for _, item in ipairs(run.items) do
		local shown = (item.quality or 0) >= 3 or showGreen
		if not shown then
			s.hidden = s.hidden + 1
		else
			local entry = type(item.source) == "number" and byKill[item.source]
			if entry then
				entry.itemCount = entry.itemCount + 1
				if item.sure then entry.sure[#entry.sure + 1] = item else entry.unsure[#entry.unsure + 1] = item end
			else
				s.trash[#s.trash + 1] = item
			end
			if item.looter then lootCount[item.looter] = (lootCount[item.looter] or 0) + 1 end
		end
	end
	s.duration = run.completedAt or Run.Elapsed(run)
	s.done, s.total = Run.BossProgress(run)
	s.wipes = run.wipes or 0
	s.money = run.money or 0
	s.vendor = run.vendor or 0
	s.repair = run.repair or 0
	s.balance = s.money + s.vendor - s.repair

	s.deaths, s.noDeaths = {}, {}
	for name, n in pairs(run.deaths) do
		if not Run.IsPlaceholder(name) then s.deaths[#s.deaths + 1] = { name = name, n = n } end
	end
	table.sort(s.deaths, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.name < b.name end)
	for name in pairs(run.players) do
		if not run.deaths[name] and not Run.IsPlaceholder(name) then s.noDeaths[#s.noDeaths + 1] = name end
	end
	table.sort(s.noDeaths)

	for _, kill in ipairs(run.kills) do
		if kill.fight and (not s.fastest or kill.fight < s.fastest.fight) then s.fastest = kill end
	end
	for name, n in pairs(lootCount) do
		if not s.mostLoot or n > s.mostLoot.n or (n == s.mostLoot.n and name < s.mostLoot.name) then
			s.mostLoot = { name = name, n = n }
		end
	end
	if s.deaths[1] then s.mostDeaths = s.deaths[1] end
	s.highlights = Run.Highlights(run, s, lootCount)
	return s
end

--[[
Highlights: every candidate gets a score for how remarkable it is this run (0-100); the four
best are shown (Felix, 22.11.2026). Equal scores: order of HIGHLIGHT_ORDER. Entries:
{ key, score, name = player or boss, value = number, extra... } - texts are made in the UI.
]]
Run.HIGHLIGHT_ORDER = { "fastest", "hardest", "loot", "deaths", "lucky", "unlucky", "item" }
Run.HIGHLIGHTS_SHOWN = 4

local function clamp(x) return math.max(0, math.min(100, x)) end

function Run.Highlights(run, s, lootCount)
	local list = {}
	local function add(h) list[#list + 1] = h end

	-- fights: fastest and hardest boss
	local fights, sum = {}, 0
	for _, kill in ipairs(run.kills) do
		if kill.fight and kill.fight > 0 then
			fights[#fights + 1] = kill
			sum = sum + kill.fight
		end
	end
	local avg = #fights > 0 and sum / #fights or nil
	if s.fastest and #fights >= 2 then
		add({ key = "fastest", name = s.fastest.name, value = s.fastest.fight,
			score = clamp(20 + 80 * math.max(0, 1 - s.fastest.fight / avg)) })
	end
	local worst, wipes = nil, 0
	for _, kill in ipairs(run.kills) do
		local n = run.bossWipes[kill.key] or 0
		if n > wipes then worst, wipes = kill, n end
	end
	if worst then
		add({ key = "hardest", name = worst.name, wipes = wipes, score = clamp(50 + 20 * wipes) })
	elseif #fights >= 2 then
		local longest = fights[1]
		for _, kill in ipairs(fights) do if kill.fight > longest.fight then longest = kill end end
		add({ key = "hardest", name = longest.name, value = longest.fight,
			score = math.min(70, clamp(15 + 60 * math.max(0, longest.fight / avg - 1))) })
	end

	-- most loot: a clear lead is remarkable, a tie hardly
	local first, second = nil, 0
	for name, n in pairs(lootCount or {}) do
		if not first or n > first.n or (n == first.n and name < first.name) then
			if first then second = math.max(second, first.n) end
			first = { name = name, n = n }
		else
			second = math.max(second, n)
		end
	end
	if first then
		local lead = first.n - second
		add({ key = "loot", name = first.name, value = first.n, score = lead > 0 and clamp(15 + 20 * lead + 5 * first.n) or 10 })
	end

	-- most deaths
	if s.deaths[1] then
		local d = s.deaths[1]
		local tied = s.deaths[2] and s.deaths[2].n == d.n
		add({ key = "deaths", name = d.name, value = d.n, score = clamp(20 + 15 * d.n - (tied and 10 or 0)) })
	end

	-- rolls: highest roll, and who lost every need roll
	local best, needs, wins = nil, {}, {}
	for _, item in ipairs(run.items) do
		if item.looter then wins[item.looter] = (wins[item.looter] or 0) + 1 end
		for name, r in pairs(item.rolls or {}) do
			if r.value and (r.choice == "need" or r.choice == "greed")
				and (not best or r.value > best.value or (r.value == best.value and name < best.name)) then
				best = { name = name, value = r.value, choice = r.choice }
			end
			if r.choice == "need" and item.looter ~= name then needs[name] = (needs[name] or 0) + 1 end
		end
	end
	if best then
		local v = best.value
		local score = v >= 100 and 95 or v >= 99 and 85 or v >= 95 and 65 or v >= 90 and 45 or 20
		add({ key = "lucky", name = best.name, value = v, choice = best.choice, score = score })
	end
	local unlucky
	for name, n in pairs(needs) do
		if not wins[name] and (not unlucky or n > unlucky.value or (n == unlucky.value and name < unlucky.name)) then
			unlucky = { name = name, value = n }
		end
	end
	if unlucky then
		add({ key = "unlucky", name = unlucky.name, value = unlucky.value, score = clamp(10 + 20 * unlucky.value) })
	end

	-- best item: epic or better is remarkable, blue hardly
	local top
	for _, item in ipairs(run.items) do
		if (item.quality or 0) >= 3 and (not top or item.quality > top.quality) then top = item end
	end
	if top then
		add({ key = "item", name = top.looter, item = top,
			score = top.quality >= 5 and 100 or top.quality >= 4 and 85 or 10 })
	end

	local rank = {}
	for i, key in ipairs(Run.HIGHLIGHT_ORDER) do rank[key] = i end
	table.sort(list, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return rank[a.key] < rank[b.key]
	end)
	while #list > Run.HIGHLIGHTS_SHOWN do table.remove(list) end
	return list
end

-- The boss marked as "final boss": a fixed end boss, else the last required boss of a wing.
function Run.IsFinal(kill)
	return kill and (kill.final or kill.last) and true or false
end
