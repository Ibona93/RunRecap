--[[
Offline logic tests for Run Recap Forever (Lua 5.1). Run from the repository root:
    lua5.1 tests/run.lua
Loads files with a private namespace exactly like the game does (`local ADDON, ns = ...`)
and mocks only the WoW API that the tested code touches.
]]

local ns = {}
local function load(path)
	local chunk = assert(loadfile(path))
	chunk("RunRecap", ns)
end

-- Minimal WoW stubs needed while loading.
_G.unpack = _G.unpack or table.unpack
_G.GetLocale = function() return "deDE" end
_G.CreateFrame = function()
	return { SetScript = function() end, RegisterEvent = function() end, UnregisterEvent = function() end }
end
_G.SlashCmdList = {}

load("Init.lua")
for _, lang in ipairs(ns.LANGUAGES) do load("Locales/" .. lang .. ".lua") end
load("Data/Dungeons.lua")
load("Logic/Dungeons.lua")
load("Core.lua")

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed = passed + 1
		print("  ok   " .. name)
	else
		failed = failed + 1
		print("  FAIL " .. name .. (detail and ("  -> " .. detail) or ""))
	end
end

print("Helpers")
do
	local t = ns.MergeDefaults({ a = 5, nested = { x = 1 } }, { a = 1, b = 2, nested = { x = 9, y = 3 }, list = {} })
	check("MergeDefaults keeps user values", t.a == 5 and t.nested.x == 1)
	check("MergeDefaults fills missing keys (also nested)", t.b == 2 and t.nested.y == 3 and type(t.list) == "table")
	local src = { inner = { 1 } }
	local copy = ns.CopyTable(src)
	check("CopyTable copies deeply", copy.inner ~= src.inner and copy.inner[1] == 1)
	check("NormalizeLocale maps enGB/esMX/ptPT", ns.NormalizeLocale("enGB") == "enUS"
		and ns.NormalizeLocale("esMX") == "esES" and ns.NormalizeLocale("ptPT") == "ptBR"
		and ns.NormalizeLocale("deDE") == "deDE")
	check("TryCall ignores missing functions and errors", ns.TryCall(nil) == nil
		and ns.TryCall(function() error("x") end) == nil and ns.TryCall(function(a) return a + 1 end, 1) == 2)
end

print("Saved variables")
do
	_G.RunRecapDB = nil
	local db = ns.InitDB()
	check("InitDB creates RunRecapDB with defaults", _G.RunRecapDB == db and db.schema == 1
		and db.debug == false and type(db.runs) == "table")
	_G.RunRecapDB = { debug = true, runs = { { id = 1 } } }
	db = ns.InitDB()
	check("InitDB keeps existing settings and runs", db.debug == true and #db.runs == 1)
end

print("Locales")
do
	check("client locale deDE is used", ns.L.DEBUG_ON == ns.Locales.deDE.DEBUG_ON)
	check("unknown key falls back to the key", ns.L.SOME_UNKNOWN_KEY == "SOME_UNKNOWN_KEY")
	local base = ns.Locales.enUS
	for _, lang in ipairs(ns.LANGUAGES) do
		local own = ns.Locales[lang]
		local missing, badFormat = {}, {}
		for key, text in pairs(base) do
			local t = own and own[key]
			if type(t) ~= "string" or t == "" then
				missing[#missing + 1] = key
			else
				-- the same %-placeholders in the same order as English
				local a, b = {}, {}
				for p in text:gmatch("%%[%d%$]*[sd]") do a[#a + 1] = p end
				for p in t:gmatch("%%[%d%$]*[sd]") do b[#b + 1] = p end
				if table.concat(a, ",") ~= table.concat(b, ",") then badFormat[#badFormat + 1] = key end
			end
		end
		check(lang .. " has every English key", #missing == 0, table.concat(missing, ", "))
		check(lang .. " keeps the format placeholders", #badFormat == 0, table.concat(badFormat, ", "))
		local extra = {}
		for key in pairs(own or {}) do if base[key] == nil then extra[#extra + 1] = key end end
		check(lang .. " has no keys English lacks", #extra == 0, table.concat(extra, ", "))
	end
end

print("Dungeon data")
do
	local D = ns.Dungeons
	local seenEnc, dupes, seenKey, badKey, count, noFinish = {}, {}, {}, {}, 0, {}
	for mapID, dungeon in pairs(ns.DUNGEONS) do
		count = count + 1
		for _, wing in ipairs(dungeon.wings) do
			local hasFinal, required = false, 0
			for _, boss in ipairs(wing.bosses) do
				if boss.final then hasFinal = true end
				if not boss.opt then required = required + 1 end
				local k = mapID .. "/" .. boss.key
				if seenKey[k] then badKey[#badKey + 1] = k end
				seenKey[k] = true
				for _, id in ipairs(boss.ids) do
					if seenEnc[id] then dupes[#dupes + 1] = id .. " (" .. seenEnc[id] .. " / " .. boss.key .. ")" end
					seenEnc[id] = boss.key
				end
			end
			if not hasFinal and required == 0 then noFinish[#noFinish + 1] = mapID .. "/" .. wing.key end
		end
	end
	check("28 dungeons in the table", count == 28, tostring(count))
	check("every encounter ID belongs to exactly one boss", #dupes == 0, table.concat(dupes, ", "))
	check("boss keys are unique per dungeon", #badKey == 0, table.concat(badKey, ", "))
	check("every wing can be completed", #noFinish == 0, table.concat(noFinish, ", "))

	local mapID, dungeon, wing, boss = D.FindEncounter(2732)
	check("encounter 2732 = Ragefire Chasm / Oggleflint (probe run)", mapID == 389 and boss.key == "Oggleflint" and wing.key == "main")
	check("NPC 11520 = Taragaman (GetLootSourceInfo in the probe run)", select(4, D.FindNpc(11520)).key == "Taragaman")
	check("unknown encounter and NPC give nil", D.FindEncounter(1) == nil and D.FindNpc(nil) == nil)
	check("Deadmines Forever ID 2747 and old ID 2972 both = VanCleef",
		select(4, D.FindEncounter(2747)).key == "VanCleef" and select(4, D.FindEncounter(2972)).key == "VanCleef")

	-- Replay of the probe run: Oggleflint, Taragaman, Bazzalan, Jergosh (wipe, then kill).
	local killed, results = {}, {}
	for _, id in ipairs({ 2732, 2733, 2735, 2734 }) do
		local _, _, w, b = D.FindEncounter(id)
		killed[b.key] = true
		local complete, done, total = D.WingProgress(w, killed)
		results[#results + 1] = (complete and "done" or "open") .. " " .. done .. "/" .. total
	end
	check("Ragefire: complete only after all 4 bosses, any order", table.concat(results, ", ")
		== "open 1/4, open 2/4, open 3/4, done 4/4", table.concat(results, ", "))

	local _, _, dm = D.FindEncounter(2747)
	local c1, d1, t1 = D.WingProgress(dm, { RhahkZor = true, VanCleef = true })
	local c2 = D.WingProgress(dm, { RhahkZor = true, Sneed = true, Gilnid = true, MrSmite = true, Greenskin = true, Cookie = true })
	check("Deadmines: VanCleef completes it; optional Miner Johnson/Cookie not counted", c1 and d1 == 2 and t1 == 6 and not c2,
		tostring(d1) .. "/" .. tostring(t1))
	local _, smDungeon, smWing = D.FindEncounter(447)
	check("Scarlet Monastery: Doan completes the Library wing only", smWing.key == "library"
		and D.WingProgress(smWing, { Doan = true }) and #smDungeon.wings == 4)
	local _, _, stocks = D.FindEncounter(2760)
	check("Stockade (no fixed end boss): 4 of 5 is not complete", not D.WingProgress(stocks,
		{ Targorr = true, KamDeepfury = true, Hamhock = true, BazilThredd = true }))
	check("Forever final bosses: Rath'mael, Blazeroar, Varrox", select(4, D.FindEncounter(3354)).final and select(4, D.FindEncounter(3409)).final and select(4, D.FindEncounter(3334)).final and not select(4, D.FindEncounter(3336)).final)
end

print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
