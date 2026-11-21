local _, ns = ...

--[[
Lookups on ns.DUNGEONS (Data/Dungeons.lua): which boss an encounter ID belongs to, and whether a
wing is complete. Pure logic, no WoW API - fully covered by tests/run.lua.
]]

local Dungeons = {}
ns.Dungeons = Dungeons

local byEncounter = {}   -- [encounterID] = { mapID, dungeon, wing, boss }
local byNpc = {}         -- [npcID] = same
Dungeons.byEncounter = byEncounter
Dungeons.byNpc = byNpc

local function clear(t) for k in pairs(t) do t[k] = nil end end

function Dungeons.BuildIndex()
	clear(byEncounter)
	clear(byNpc)
	for mapID, dungeon in pairs(ns.DUNGEONS or {}) do
		for _, wing in ipairs(dungeon.wings) do
			for _, boss in ipairs(wing.bosses) do
				local entry = { mapID = mapID, dungeon = dungeon, wing = wing, boss = boss }
				for _, id in ipairs(boss.ids) do byEncounter[id] = entry end
				for _, id in ipairs(boss.npc or {}) do byNpc[id] = entry end
			end
		end
	end
end

-- Returns mapID, dungeon, wing, boss for an encounter ID (nil if unknown).
function Dungeons.FindEncounter(encounterID)
	local e = byEncounter[encounterID]
	if e then return e.mapID, e.dungeon, e.wing, e.boss end
end

-- Same for an NPC ID (loot sources from GetLootSourceInfo).
function Dungeons.FindNpc(npcID)
	local e = byNpc[tonumber(npcID) or -1]
	if e then return e.mapID, e.dungeon, e.wing, e.boss end
end

--[[
Progress of a wing. `killed` is a set of boss keys ({ VanCleef = true, ... }).
Returns complete (bool), killedRequired, totalRequired.
Complete when a final boss is dead, or - in a wing without a final boss - when every
non-optional boss is dead (e.g. Ragefire Chasm, The Stockade).
]]
function Dungeons.WingProgress(wing, killed)
	local hasFinal, finalDead, total, done = false, false, 0, 0
	for _, boss in ipairs(wing.bosses) do
		if boss.final then
			hasFinal = true
			if killed[boss.key] then finalDead = true end
		end
		if not boss.opt then
			total = total + 1
			if killed[boss.key] then done = done + 1 end
		end
	end
	local complete
	if hasFinal then complete = finalDead else complete = total > 0 and done == total end
	return complete, done, total
end

Dungeons.BuildIndex()
