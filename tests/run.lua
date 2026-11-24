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
_G.strsplit = function(sep, str)
	local out = {}
	for part in (str .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = part end
	return unpack(out)
end

load("Init.lua")
for _, lang in ipairs(ns.LANGUAGES) do load("Locales/" .. lang .. ".lua") end
load("Data/Dungeons.lua")
load("Logic/Dungeons.lua")
load("Logic/Parse.lua")
load("Logic/Run.lua")
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


-- deDE global strings exactly as the probe recorded them in the Forever client (21.11.2026).
local DE = {
	LOOT_ITEM = "%s bekommt Beute: %s.",
	LOOT_ITEM_SELF = "Ihr erhaltet Beute: %s",
	LOOT_ITEM_MULTIPLE = "%s erhält Beute: %sx%d.",
	LOOT_ITEM_SELF_MULTIPLE = "Ihr erhaltet Beute: %sx%d",
	LOOT_ITEM_PUSHED_SELF = "Ihr erhaltet einen Gegenstand: %s",
	LOOT_ROLL_NEED = "|HlootHistory:%d|h[Beute]|h: %s hat für %s Bedarf ausgewählt",
	LOOT_ROLL_NEED_SELF = "|HlootHistory:%d|h[Beute]|h: Ihr habt \"Bedarf\" ausgewählt für: %s",
	LOOT_ROLL_GREED = "|HlootHistory:%d|h[Beute]|h: %s hat für %s Gier ausgewählt",
	LOOT_ROLL_GREED_SELF = "|HlootHistory:%d|h[Beute]|h: Ihr habt \"Gier\" ausgewählt für: %s",
	LOOT_ROLL_PASSED = "|HlootHistory:%d|h[Beute]|h: Weitergegeben von %s: %s",
	LOOT_ROLL_PASSED_SELF = "|HlootHistory:%d|h[Beute]|h: Weitergegeben von Euch: %s",
	LOOT_ROLL_PASSED_AUTO = "%1$s passt automatisch auf %2$s, weil er den Gegenstand nicht benutzen kann.",
	LOOT_ROLL_ALL_PASSED = "|HlootHistory:%d|h[Beute]|h: Alle haben gepasst auf: %s",
	LOOT_ROLL_ROLLED_NEED = "|HlootHistory:%d|h[Beute]|h: Wurf für eigenen Bedarf: %d für %s von %s",
	LOOT_ROLL_ROLLED_GREED = "|HlootHistory:%d|h[Beute]|h: Wurf für Gold: %d für %s von %s",
	LOOT_ROLL_WON = "|HlootHistory:%d|h[Beute]|h: Gewonnen von %s: %s",
	LOOT_ROLL_YOU_WON = "|HlootHistory:%d|h[Beute]|h: Gewonnen von Euch: %s",
	LOOT_ROLL_WON_NO_SPAM_NEED = "|HlootHistory:%d|h[Beute]|h: %s hat gewonnen (Bedarf - %d, Primäre Spezialisierung): %s",
	LOOT_ROLL_WON_NO_SPAM_GREED = "|HlootHistory:%d|h[Beute]|h: %s (Gier - %d) Gewonnen: %s",
	LOOT_MONEY_SPLIT = "Euer Anteil an der Beute ist %s.",
	YOU_LOOT_MONEY = "Ihr plündert %s",
	LOOT_MONEY = "%1$s plündert %2$s",
	GOLD_AMOUNT = "%d Gold", SILVER_AMOUNT = "%d Silber", COPPER_AMOUNT = "%d Kupfer",
	INSTANCE_RESET_SUCCESS = "%s wurde zurückgesetzt.",
}
for k, v in pairs(DE) do _G[k] = v end

local ARMBRUST = "|cnIQ3:|Hitem:272999::::::::13:1490::1:::::::|h[Barbarische Armbrust]|h|r"
local MANSCHETTEN = "|cnIQ3:|Hitem:14148::::::::13:1490::1:::::::|h[Kristallene Manschetten]|h|r"
local SCHILD = "|cnIQ2:|Hitem:15494::::::::13:1490::1:1:12730::::::|h[Blutbespritzter Schild der Willenskraft]|h|r"
local STOCK = "|cnIQ2:|Hitem:15945::::::::13:1490::1::1:28:5244:::::|h[Runenverzierter Stock]|h|r"
local MILCH = "|cnIQ1:|Hitem:1179::::::::13:1490:::::::::|h[Eiskalte Milch]|h|r"
local LEINEN = "|cnIQ1:|Hitem:2589::::::::13:1490:::::::::|h[Leinenstoff]|h|r"
local PERLE = "|cnIQ2:|Hitem:5498::::::::13:1490:::::::::|h[Kleine irisierende Perle]|h|r"
local function H(id) return "|HlootHistory:" .. id .. "|h[Beute]|h: " end

print("Parsing")
do
	local P = ns.Parse
	local pat, order = P.FormatToPattern("%1$s passt auf %2$s.")
	check("FormatToPattern: positional args and escaping", pat == "^(.-) passt auf (.-)%.$" and order[1] == 1 and order[2] == 2, pat)
	local a = P.Match("%2$s von %1$s", "Stock von Kesh")
	check("Match returns arguments in format order", a and a[1] == "Kesh" and a[2] == "Stock")
	check("item ID, name and quality from Forever links", P.ItemID(ARMBRUST) == 272999 and P.ItemName(ARMBRUST) == "Barbarische Armbrust"
		and P.ItemQuality(ARMBRUST) == 3 and P.ItemQuality(MILCH) == 1)
	check("quality from classic colour codes", P.ItemQuality("|cff0070dd|Hitem:5191::::|h[Cruel Barb]|h|r") == 3
		and P.ItemQuality("|cffa335ee|Hitem:1::::|h[X]|h|r") == 4)

	local l = P.Loot("Albona Lichtwirker bekommt Beute: " .. PERLE .. ".")
	check("LOOT_ITEM: other player (name with space)", l and l.player == "Albona Lichtwirker" and l.link == PERLE and l.count == 1 and not l.self)
	l = P.Loot("Ihr erhaltet Beute: " .. STOCK)
	check("LOOT_ITEM_SELF (no full stop in deDE)", l and l.self and l.link == STOCK)
	l = P.Loot("Albona Lichtwirker erhält Beute: " .. LEINEN .. "x4.")
	check("LOOT_ITEM_MULTIPLE with count", l and l.player == "Albona Lichtwirker" and l.count == 4 and l.link == LEINEN)
	l = P.Loot("Ihr erhaltet Beute: " .. LEINEN .. "x3")
	check("LOOT_ITEM_SELF_MULTIPLE", l and l.self and l.count == 3 and l.link == LEINEN)
	check("quest items and crafting are no loot", P.Loot("Ihr erhaltet einen Gegenstand: " .. MILCH) == nil
		and P.Loot("Ihr stellt her: " .. MILCH .. ".") == nil)
	check("roll lines are not parsed as loot", P.Loot(H(1) .. "Gewonnen von Kesh: " .. STOCK) == nil)

	local r = P.Roll(H(4470529) .. ARMBRUST)
	check("roll announcement", r and r.kind == "start" and r.historyID == 4470529 and r.link == ARMBRUST)
	r = P.Roll(H(4470529) .. "Wurf für Gold: 88 für " .. ARMBRUST .. " von Tarosh Dolchhieb")
	check("greed roll with number", r and r.kind == "roll" and r.roll == "greed" and r.value == 88 and r.player == "Tarosh Dolchhieb")
	r = P.Roll(H(7) .. "Wurf für eigenen Bedarf: 99 für " .. STOCK .. " von Albona Lichtwirker")
	check("need roll with number", r and r.roll == "need" and r.value == 99 and r.historyID == 7)
	r = P.Roll(H(7) .. "Tarosh Dolchhieb hat für " .. STOCK .. " Gier ausgewählt")
	check("greed chosen", r and r.kind == "choice" and r.roll == "greed" and r.player == "Tarosh Dolchhieb")
	r = P.Roll(H(7) .. "Ihr habt \"Bedarf\" ausgewählt für: " .. STOCK)
	check("own need chosen", r and r.kind == "choice" and r.roll == "need" and r.self)
	r = P.Roll(H(7) .. "Weitergegeben von Balerdroch Sheridan: " .. STOCK)
	check("passed", r and r.roll == "pass" and r.player == "Balerdroch Sheridan")
	r = P.Roll(H(7) .. "Gewonnen von Euch: " .. STOCK)
	check("won by me (YOU_WON before WON)", r and r.kind == "won" and r.self and r.player == nil)
	r = P.Roll(H(7) .. "Gewonnen von Albona Lichtwirker: " .. STOCK)
	check("won by another player", r and r.kind == "won" and r.player == "Albona Lichtwirker")
	r = P.Roll(H(7) .. "Kesh hat gewonnen (Bedarf - 87, Primäre Spezialisierung): " .. STOCK)
	check("won (no spam) with number", r and r.kind == "won" and r.player == "Kesh" and r.value == 87 and r.roll == "need")
	r = P.Roll(H(7) .. "Alle haben gepasst auf: " .. STOCK)
	check("all passed", r and r.kind == "allpassed")
	check("ordinary loot is no roll", P.Roll("Ihr erhaltet Beute: " .. STOCK) == nil)

	check("money: share in copper", P.Money("Euer Anteil an der Beute ist 13 Kupfer.") == 13)
	check("money: gold, silver, copper", P.Money("Ihr plündert 1 Gold, 2 Silber, 3 Kupfer") == 10203)
	check("money of others is ignored", P.Money("Kesh plündert 5 Kupfer") == nil)
	local npc, inst, zone = P.CreatureGUID("Creature-0-6939-389-4711-11517-0000ABC")
	check("creature GUID: NPC, instance, copy", npc == 11517 and inst == 389 and zone == "4711")
	check("player GUID is no creature", P.CreatureGUID("Player-6939-00FF6C87") == nil)
	check("clock format", P.Clock(2537) == "42:17" and P.Clock(48) == "0:48" and P.Clock(3723) == "1:02:03")
	check("coins with icons", P.Coins(10203):find("^1|TInterface\\MoneyFrame\\UI%-GoldIcon") ~= nil and select(2, P.Coins(13):gsub("|T", "")) == 1)
end

print("Run logic")
do
	local R = ns.Run
	local clock = 1000
	local function now() return clock end
	ns.Now = now
	_G.RunRecapDB = nil
	ns.InitDB()
	local completed
	R.onComplete = function(run) completed = run end
	local inside = { inInstance = true, instanceType = "party", mapID = 389, name = "Ragefireabgrund" }

	local run = R.OnZone(inside)
	check("entering Ragefire starts a run", run and ns.db.currentRun == run and run.name == "Ragefireabgrund" and run.state == "active")
	check("entering an unknown/outdoor zone starts nothing", (function()
		local d = ns.db.currentRun ns.db.currentRun = nil
		local r = R.OnZone({ inInstance = false }) ns.db.currentRun = d return r == nil end)())
	for _, n in ipairs({ "Ibona Hexfang", "Albona Lichtwirker", "Tarosh Dolchhieb", "Ursabor Wunderwuchs", "Balerdroch Sheridan" }) do
		R.SetPlayer(run, n, "WARLOCK")
	end

	-- trash before the first boss: green roll, own loot window says NPC 11318 (trash)
	clock = 1100
	R.OnRoll(run, ns.Parse.Roll(H(4461825) .. STOCK), "Ibona Hexfang")
	R.OnLootWindow(run, { { link = STOCK, npc = 11318 } })
	R.OnRoll(run, ns.Parse.Roll(H(4461825) .. "Gewonnen von Euch: " .. STOCK), "Ibona Hexfang")
	R.OnLoot(run, ns.Parse.Loot("Ihr erhaltet Beute: " .. STOCK), "Ibona Hexfang")
	check("trash roll: one item, won by me, source trash (sure)", #run.items == 1 and run.items[1].looter == "Ibona Hexfang"
		and run.items[1].source == "trash" and run.items[1].sure and run.items[1].claimed)
	R.OnLoot(run, ns.Parse.Loot("Ihr erhaltet Beute: " .. MILCH), "Ibona Hexfang")
	check("white loot is not kept", #run.items == 1)
	R.OnMoney(run, ns.Parse.Money("Euer Anteil an der Beute ist 13 Kupfer."))

	-- Oggleflint: kill, blue roll right after (rule 2: roll timing)
	clock = 1200
	R.OnEncounterStart(run, 2732, "Flintauge")
	clock = 1245
	R.OnEncounterEnd(run, 2732, "Flintauge", 1)
	check("boss kill with run time and fight duration", #run.kills == 1 and run.kills[1].at == 245 and run.kills[1].fight == 45)
	clock = 1246
	R.OnRollStart(run, 4470529, ARMBRUST)
	R.OnRoll(run, ns.Parse.Roll(H(4470529) .. "Wurf für Gold: 88 für " .. ARMBRUST .. " von Tarosh Dolchhieb"), "Ibona Hexfang")
	R.OnRoll(run, ns.Parse.Roll(H(4470529) .. "Wurf für Gold: 49 für " .. ARMBRUST .. " von Ibona Hexfang"), "Ibona Hexfang")
	R.OnRoll(run, ns.Parse.Roll(H(4470529) .. "Weitergegeben von Balerdroch Sheridan: " .. ARMBRUST), "Ibona Hexfang")
	R.OnRoll(run, ns.Parse.Roll(H(4470529) .. "Gewonnen von Tarosh Dolchhieb: " .. ARMBRUST), "Ibona Hexfang")
	R.OnLoot(run, ns.Parse.Loot("Tarosh Dolchhieb bekommt Beute: " .. ARMBRUST .. "."), "Tarosh Dolchhieb", "ROGUE")
	local armbrust = run.items[2]
	check("boss roll: source = Oggleflint (sure), winner Tarosh, no duplicate", #run.items == 2 and armbrust.source == 1
		and armbrust.sure and armbrust.looter == "Tarosh Dolchhieb" and not armbrust.rolling and run.players["Tarosh Dolchhieb"] == "ROGUE")
	local rolls = R.SortedRolls(armbrust)
	check("rolls sorted: greed by number, pass last", #rolls == 3 and rolls[1].name == "Tarosh Dolchhieb" and rolls[1].value == 88
		and rolls[3].choice == "pass")
	check("learned: Armbrust -> Oggleflint", ns.db.learned[272999] == "389:Oggleflint")

	-- a green item another player loots directly soon after the kill: "probably" the boss
	clock = 1260
	R.OnLoot(run, ns.Parse.Loot("Albona Lichtwirker bekommt Beute: " .. PERLE .. "."), "Albona Lichtwirker")
	check("direct loot of others after a kill: probably that boss", run.items[3].source == 1 and run.items[3].sure == false)
	clock = 1500
	R.OnLoot(run, ns.Parse.Loot("Albona Lichtwirker bekommt Beute: " .. PERLE .. "."), "Albona Lichtwirker")
	check("... long after a kill: trash", run.items[4].source == "trash")

	-- a death in a wipe at Jergosh, then everything else
	clock = 1600
	R.OnEncounterStart(run, 2734, "Jergosh der Herbeirufer")
	R.OnUnitState(run, "Ibona Hexfang", true)
	R.OnUnitState(run, "Ibona Hexfang", true)
	clock = 1640
	R.OnEncounterEnd(run, 2734, "Jergosh der Herbeirufer", 0)
	check("wipe counted, death counted once, death listed at the boss", run.wipes == 1 and run.bossWipes.Jergosh == 1
		and run.deaths["Ibona Hexfang"] == 1 and run.bossDeaths.Jergosh[1] == "Ibona Hexfang")

	-- leaving as a ghost: run keeps going
	R.OnZone({ inInstance = false, dead = true })
	check("leaving as a ghost: run keeps running", run.state == "active")
	R.OnZone(inside)
	R.OnUnitState(run, "Ibona Hexfang", false)

	clock = 1700
	R.OnEncounterStart(run, 2733, "Taragaman der Hungerleider")
	clock = 1741
	R.OnEncounterEnd(run, 2733, "Taragaman der Hungerleider", 1)
	clock = 1742
	R.OnRollStart(run, 4494341, SCHILD)
	R.OnRollStart(run, 4494338, MANSCHETTEN)
	R.OnLootWindow(run, { { link = MANSCHETTEN, npc = 11520 }, { link = SCHILD, npc = 11520 } })
	clock = 1786
	R.OnRoll(run, ns.Parse.Roll(H(4494338) .. "Gewonnen von Ursabor Wunderwuchs: " .. MANSCHETTEN), "Ibona Hexfang")
	R.OnLoot(run, ns.Parse.Loot("Ursabor Wunderwuchs bekommt Beute: " .. MANSCHETTEN .. "."), "Ursabor Wunderwuchs")
	check("two drops of Taragaman, loot window confirms the boss", run.items[5].source == 2 and run.items[6].source == 2
		and run.items[6].fromWindow and run.items[6].looter == "Ursabor Wunderwuchs")

	-- leaving alive (hearthstone to a vendor): paused, pause time not counted
	clock = 1800
	R.OnZone({ inInstance = false, dead = false })
	check("leaving alive: paused", run.state == "paused")
	clock = 2400
	check("not ended before 30 minutes", not R.CheckTimeout() and ns.db.currentRun == run)
	R.OnZone(inside)
	check("back: resumed, 600 s pause left out, same run", run.state == "active" and R.Elapsed(run) == 800 and ns.db.currentRun == run)

	clock = 2500
	R.OnEncounterEnd(run, 2735, "Bazzalan", 1)
	check("3 of 4: not complete", not run.completed and completed == nil)
	R.OnEncounterEnd(run, 2735, "Bazzalan", 1)
	check("a second kill message for the same boss is ignored", #run.kills == 3)
	clock = 2600
	R.OnEncounterStart(run, 2734, "Jergosh der Herbeirufer")
	clock = 2660
	R.OnEncounterEnd(run, 2734, "Jergosh der Herbeirufer", 1)
	check("4 of 4 in any order: complete, callback fired", run.completed and completed == run and run.completedAt == 1060
		and run.kills[4].last and R.IsFinal(run.kills[4]) and not R.IsFinal(run.kills[1]))
	check("Latest() shows the completed current run", R.Latest() == run)

	-- the learned item drops again in a later run: sure without window or roll
	local s = R.Summary(run, false)
	check("summary: 4 bosses, progress 4/4, 1 wipe, 13 copper", #s.bosses == 4 and s.done == 4 and s.total == 4 and s.wipes == 1 and s.money == 13)
	check("summary: green hidden by default, blue shown", s.hidden == 4 and #s.bosses[1].sure == 1 and #s.bosses[2].sure == 1 and #s.trash == 0,
		("hidden %d"):format(s.hidden))
	s = R.Summary(run, true)
	check("summary with green: probable item under its boss, trash section", #s.bosses[1].unsure == 1 and #s.trash == 2 and s.hidden == 0)
	check("summary: deaths, players without deaths, highlights", s.deaths[1].name == "Ibona Hexfang" and #s.noDeaths == 4
		and s.fastest.key == "Taragaman" and s.mostDeaths.n == 1 and s.mostLoot ~= nil)

	-- leaving alive after the run; 30 minutes outside end it -> history
	clock = 2700
	R.OnZone({ inInstance = false, dead = false })
	clock = 2700 + 30 * 60
	check("30 minutes outside: run ended and kept in the history", R.CheckTimeout() and ns.db.currentRun == nil
		and ns.db.runs[#ns.db.runs] == run and run.state == "finished")

	-- new run: learned item, aborted run, reset, other instance
	clock = 10000
	local run2 = R.OnZone(inside)
	R.OnEncounterEnd(run2, 2732, "Flintauge", 1)
	clock = 10500
	R.OnLoot(run2, ns.Parse.Loot("Kesh bekommt Beute: " .. ARMBRUST .. "."), "Kesh")
	check("learned item: sure source without roll or window", run2.items[1].source == 1 and run2.items[1].sure and run2.items[1].learned)
	R.OnZone({ inInstance = false, dead = false })
	R.OnInstanceReset()
	check("reset while outside: aborted run dropped (no history entry)", ns.db.currentRun == nil and ns.db.runs[#ns.db.runs] == run)
	local run3 = R.OnZone(inside)
	R.OnZone({ inInstance = false, dead = false })
	R.OnZone(inside)
	check("not completed, out and back in: still the same run", ns.db.currentRun == run3 and run3.state == "active")
	for _, e in ipairs({ { 2732, "Flintauge" }, { 2733, "Taragaman" }, { 2735, "Bazzalan" }, { 2734, "Jergosh" } }) do
		R.OnEncounterEnd(run3, e[1], e[2], 1)
	end
	R.OnZone({ inInstance = false, dead = false })
	R.OnZone(inside)
	check("completed, left alive, back in: a new run, the old one kept", ns.db.currentRun ~= run3 and ns.db.runs[#ns.db.runs] == run3
		and #ns.db.currentRun.kills == 0)
	R.OnZone({ inInstance = true, instanceType = "party", mapID = 36, name = "Die Todesminen" })
	check("other dungeon: new run there", ns.db.currentRun.mapID == 36)
	ns.db.currentRun.lastSeen = clock
	clock = clock + 31 * 60
	R.OnLogin()
	check("login 31 min after the last activity: old run over", ns.db.currentRun == nil)

	-- Deadmines: Van Cleef is the end boss, optional bosses do not count
	local dm = R.OnZone({ inInstance = true, instanceType = "party", mapID = 36, name = "Die Todesminen" })
	R.OnEncounterEnd(dm, 2741, "Rhahk'Zor", 1)
	R.OnEncounterEnd(dm, 2747, "Edwin van Cleef", 1)
	local d, t = R.BossProgress(dm)
	check("Deadmines: Van Cleef completes it; progress 2/6", dm.completed and dm.kills[2].final and d == 2 and t == 6)
	R.OnEncounterEnd(dm, 99999, "Unbekannt", 1)
	check("unknown encounter is listed, but changes nothing", #dm.kills == 3 and dm.kills[3].opt)

	-- highlights: scores pick the 4 most remarkable
	local hr = { kills = {
			{ key = "A", name = "A", fight = 10 }, { key = "B", name = "B", fight = 60 }, { key = "C", name = "C", fight = 50 },
		}, bossWipes = { B = 3 }, items = {
			{ quality = 4, looter = "Kesh", link = "x", rolls = { Kesh = { choice = "need", value = 100 }, Bram = { choice = "need", value = 40 } } },
			{ quality = 3, looter = "Kesh", link = "y", rolls = { Kesh = { choice = "need", value = 50 }, Bram = { choice = "need", value = 20 } } },
			{ quality = 3, looter = "Lyss", link = "z", rolls = { Bram = { choice = "need", value = 10 }, Lyss = { choice = "need", value = 30 } } },
		}, deaths = {}, players = {} }
	local hs = { fastest = hr.kills[1], deaths = {} }
	local list = R.Highlights(hr, hs, { Kesh = 2, Lyss = 1 })
	local keys = {}
	for k, h in ipairs(list) do keys[k] = h.key end
	check("highlights: max. 4, sorted by score (hardest 3 wipes, lucky 100, item epic, fastest)",
		#list == 4 and keys[1] == "hardest" and keys[2] == "lucky" and keys[3] == "item" and keys[4] == "fastest", table.concat(keys, ","))
	check("highlights: unlucky Bram (3x need, no win) scores 70 but is 5th", (function()
		R.HIGHLIGHTS_SHOWN = 10
		local all = R.Highlights(hr, hs, { Kesh = 2, Lyss = 1 })
		R.HIGHLIGHTS_SHOWN = 4
		for _, h in ipairs(all) do if h.key == "unlucky" then return h.name == "Bram" and h.value == 3 and h.score == 70 end end
	end)())
	check("highlights: a tie for most loot hardly counts", (function()
		for _, h in ipairs(R.Highlights(hr, hs, { Kesh = 1, Lyss = 1 })) do if h.key == "loot" then return false end end
		return true
	end)())

	-- money: vendor value of own loot (not need-won items), repair costs, balance
	clock = 50000
	local mr = R.OnZone({ inInstance = true, instanceType = "party", mapID = 389, name = "Ragefireabgrund" })
	local prices = { [1179] = 6, [272999] = 5000, [5498] = 100 }
	ns.SellPrice = function(link) return prices[ns.Parse.ItemID(link)] or 0 end
	R.OnLoot(mr, ns.Parse.Loot("Ihr erhaltet Beute: " .. MILCH .. "x3"), "Ibona Hexfang")
	check("vendor value: white loot counts (3 x 6)", mr.vendor == 18)
	R.OnLoot(mr, ns.Parse.Loot("Albona Lichtwirker bekommt Beute: " .. PERLE .. "."), "Albona Lichtwirker")
	check("vendor value: loot of others does not count", mr.vendor == 18)
	R.OnRollStart(mr, 77, ARMBRUST)
	R.OnRoll(mr, ns.Parse.Roll(H(77) .. "Ihr habt \"Bedarf\" ausgewählt für: " .. ARMBRUST), "Ibona Hexfang")
	R.OnRoll(mr, ns.Parse.Roll(H(77) .. "Gewonnen von Euch: " .. ARMBRUST), "Ibona Hexfang")
	R.OnLoot(mr, ns.Parse.Loot("Ihr erhaltet Beute: " .. ARMBRUST), "Ibona Hexfang")
	check("vendor value: item won with need does not count", mr.vendor == 18)
	R.OnRollStart(mr, 78, PERLE)
	R.OnRoll(mr, ns.Parse.Roll(H(78) .. "Ihr habt \"Gier\" ausgewählt für: " .. PERLE), "Ibona Hexfang")
	R.OnRoll(mr, ns.Parse.Roll(H(78) .. "Gewonnen von Euch: " .. PERLE), "Ibona Hexfang")
	R.OnLoot(mr, ns.Parse.Loot("Ihr erhaltet Beute: " .. PERLE), "Ibona Hexfang")
	check("vendor value: item won with greed counts", mr.vendor == 118)
	local function rs(a, b, idA) return { [1] = { cost = a, id = idA or 100 }, [5] = { cost = b, id = 200 } } end
	R.OnRepairSample(mr, rs(200, 300))
	R.OnRepairSample(mr, rs(400, 500))
	check("repairs: increases per slot count", mr.repair == 400)
	R.OnRepairSample(mr, { [5] = { cost = 500, id = 200 } })
	R.OnRepairSample(mr, rs(400, 500))
	check("repairs: a slot that can't be read for a moment is not counted twice", mr.repair == 400)
	R.OnRepairSample(mr, rs(100, 500))
	R.OnRepairSample(mr, rs(400, 500))
	check("repairs: a slot reading low for a moment is not counted twice", mr.repair == 400)
	R.OnRepairSample(mr, rs(900, 500, 101))
	R.OnRepairSample(mr, rs(1000, 600, 101))
	check("repairs: another item in the slot only moves the base", mr.repair == 600)
	R.OnRepairSample(mr, rs(1500, 600, 101), true)
	check("repairs: gear change / vendor only moves the base", mr.repair == 600)
	R.Pause(mr)
	R.OnRepairSample(mr, rs(0, 0, 101))
	R.Resume(mr)
	R.OnRepairSample(mr, rs(200, 100, 101))
	check("repaired at a vendor while outside: new base, nothing lost", mr.repair == 900)
	R.OnMoney(mr, 1000)
	local ms = R.Summary(mr, true)
	check("balance = gold + vendor value - repairs", ms.money == 1000 and ms.vendor == 118 and ms.repair == 900 and ms.balance == 218)
	R.OnQuestMoney(mr, 250)
	R.OnQuestMoney(mr, 0)
	check("quest gold inside the instance counts as gold", mr.money == 1250)
	ns.SellPrice = nil
	R.End("test")

	-- Gnomeregan 23.11.2026: no ENCOUNTER_END for Elektrokutionator 6000, wipe on trash,
	-- "Unbekannt" in the group
	clock = 60000
	UNKNOWNOBJECT = "Unbekannt" -- luacheck: ignore
	local gr = R.OnZone({ inInstance = true, instanceType = "party", mapID = 90, name = "Gnomeregan" })
	R.SetPlayer(gr, "Unbekannt", "ROGUE")
	R.SetPlayer(gr, "Ibona", "PALADIN")
	R.SetGroup(gr, { "Ibona", "Lass", "Dan", "Testo", "Shacos", "Unbekannt" })
	gr.alias = { Lass = "Lass Mi" } -- learned from a chat line meanwhile
	R.OnUnitState(gr, "Unbekannt", true)
	check("placeholder name: not a player, no death", gr.players.Unbekannt == nil and gr.deaths.Unbekannt == nil)
	R.OnUnitState(gr, "Lass", true)
	R.OnUnitState(gr, "Dan", true)
	R.OnUnitState(gr, "Testo", true)
	check("3 of 5 dead: no wipe yet", gr.wipes == 0)
	R.OnUnitState(gr, "Shacos", true)
	check("trash wipe: all but one dead (paladin bubble) counts, full names too", gr.wipes == 1 and gr.deadNow["Lass Mi"])
	R.OnUnitState(gr, "Ibona", true)
	check("trash wipe: counted once", gr.wipes == 1)
	for _, n in ipairs({ "Ibona", "Lass", "Dan", "Testo" }) do R.OnUnitState(gr, n, false) end
	check("trash wipe: not over while someone is still dead", gr.groupWiped == true)
	R.OnUnitState(gr, "Shacos", false)
	R.OnUnitState(gr, "Shacos", true)
	R.OnUnitState(gr, "Lass", true)
	check("alive again, two die: no new wipe", gr.wipes == 1)
	R.OnUnitState(gr, "Shacos", false)
	R.OnUnitState(gr, "Lass", false)
	clock = clock + 300
	R.OnLootWindow(gr, { { link = PERLE, npc = 6235, npcName = "Elektrokutionator 6000" } })
	local ek = gr.kills[gr.killed.Electrocutioner]
	check("loot window of a boss without ENCOUNTER_END: the kill is added", ek ~= nil and ek.name == "Elektrokutionator 6000"
		and ek.fromNpc and ek.at == 300 and gr.kills[#gr.kills] == ek)
	R.OnRollStart(gr, 901, PERLE)
	local leg
	for _, it in ipairs(gr.items) do if it.historyID == 901 then leg = it end end
	check("its loot belongs to that boss", leg and leg.source == gr.killed.Electrocutioner and leg.sure)
	clock = clock + 60
	R.OnEncounterStart(gr, 2771, "Meuteverprügler 9-60")
	R.OnBossDead(gr, 6229, "Meuteverprügler 9-60")
	check("dead boss during its fight: wait for ENCOUNTER_END", gr.killed.CrowdPummeler == nil)
	clock = clock + 26
	R.OnEncounterEnd(gr, 2771, "Meuteverprügler 9-60", 1)
	check("then the normal kill with fight time", gr.kills[gr.killed.CrowdPummeler].fight == 26)
	R.OnBossDead(gr, 7361, "Grubbis")
	clock = clock + 5
	R.OnEncounterEnd(gr, 2768, "Grubbis", 1)
	local gk = gr.kills[gr.killed.Grubbis]
	check("dead boss seen first, ENCOUNTER_END later: one kill, fight added", #gr.kills == 3 and gk.encounterID == 2768 and not gk.fromNpc)
	R.OnBossDead(gr, 1234, "Irgendwer")
	check("other NPCs: nothing", #gr.kills == 3)
	local gs = R.Summary(gr, true)
	local listed = false
	for _, n in ipairs(gs.noDeaths) do if n == "Unbekannt" then listed = true end end
	gr.players.Unbekannt = "ROGUE" -- runs saved before the fix
	for _, n in ipairs(R.Summary(gr, true).noDeaths) do if n == "Unbekannt" then listed = true end end
	check("summary: no \"Unbekannt\"", not listed)
	check("kill minute past an hour: 66:12", ns.Parse.Minutes(3972) == "66:12" and ns.Parse.Minutes(59) == "0:59")
	R.End("test")

	-- Rare elites (Friedhof, 24.11.2026): no encounter, shown only when killed, never in x/y
	clock = 90000
	local gy = R.OnZone({ inInstance = true, instanceType = "party", mapID = 189, name = "Scharlachrotes Kloster" })
	R.OnEncounterEnd(gy, 444, "Befrager Vishas", 1)
	local _, before = R.BossProgress(gy)
	clock = clock + 200
	R.OnLootWindow(gy, { { link = PERLE, npc = 6489, npcName = "Eisenrücken" } })
	local spine = gy.kills[gy.killed.Ironspine]
	check("rare: its loot window adds it as a rare kill", spine and spine.rare and spine.opt and spine.name == "Eisenrücken")
	local done, total = R.BossProgress(gy)
	check("rare: not counted in bosses x/y", done == 1 and total == before and total == 2)
	check("rare: does not complete the wing", not gy.completed)
	R.OnRollStart(gy, 777, PERLE)
	local rareItem
	for _, it in ipairs(gy.items) do if it.historyID == 777 then rareItem = it end end
	check("rare: its loot is listed under it, not under trash", rareItem and rareItem.source == gy.killed.Ironspine)
	R.OnEncounterEnd(gy, 445, "Blutmagier Thalnos", 1)
	check("rare: the wing still completes with its real bosses", gy.completed and gy.completedWings.graveyard)
	R.End("test")

	-- data: every NPC ID belongs to one boss only
	local seen, dup = {}, nil
	for _, dg in pairs(ns.DUNGEONS) do
		for _, wing in ipairs(dg.wings) do
			for _, boss in ipairs(wing.bosses) do
				for _, id in ipairs(boss.npc or {}) do
					if seen[id] then dup = id end
					seen[id] = true
				end
				if boss.rare and (not boss.opt or boss.final) then dup = boss.key end
			end
		end
	end
	check("dungeon data: NPC IDs unique, rares always optional and never final", dup == nil, tostring(dup))

	-- Dalaran (23.11.2026): first names from the unit functions, full names in chat lines
	clock = 60000
	R.End("test")
	local dal = R.OnZone({ inInstance = true, instanceType = "party", mapID = 2959, name = "Dalaran" })
	R.SetPlayer(dal, "Ibona", "PALADIN")
	R.SetPlayer(dal, "Anna", "WARLOCK")
	local KNOCHEN = "|cnIQ3:|Hitem:273001::::::::30:1490:::::::::|h[Knochenhaufenblick]|h|r"
	R.OnRollStart(dal, 901, KNOCHEN)
	R.OnRoll(dal, ns.Parse.Roll(H(901) .. "Ihr habt \"Bedarf\" ausgewählt für: " .. KNOCHEN), "Ibona")
	R.OnRoll(dal, ns.Parse.Roll(H(901) .. "Wurf für eigenen Bedarf: 22 für " .. KNOCHEN .. " von Ibona Lightgrave"), "Ibona")
	R.OnRoll(dal, ns.Parse.Roll(H(901) .. "Wurf für Gold: 40 für " .. KNOCHEN .. " von Anna Kramer"), "Ibona")
	R.OnRoll(dal, ns.Parse.Roll(H(901) .. "Gewonnen von Euch: " .. KNOCHEN), "Ibona")
	R.OnLoot(dal, ns.Parse.Loot("Ihr erhaltet Beute: " .. KNOCHEN), "Ibona Lightgrave", "PALADIN")
	check("Dalaran: first and full name are one player", dal.players["Ibona"] == nil and dal.players["Ibona Lightgrave"] == "PALADIN"
		and dal.players["Anna"] == nil and dal.players["Anna Kramer"] == "WARLOCK")
	check("Dalaran: item won by me and then looted = one item, rolls merged", #dal.items == 1 and dal.items[1].looter == "Ibona Lightgrave"
		and dal.items[1].rolls["Ibona"] == nil and dal.items[1].rolls["Ibona Lightgrave"].choice == "need"
		and dal.items[1].rolls["Ibona Lightgrave"].value == 22)
	R.OnUnitState(dal, "Anna", true)
	check("Dalaran: a death under the first name counts for the full name", dal.deaths["Anna Kramer"] == 1 and dal.deaths["Anna"] == nil)
	check("two different players with the same first name are not merged", (function()
		local t = { players = { Kim = false, ["Kim A"] = false, ["Kim B"] = false }, deaths = {}, deadNow = {}, bossDeaths = {}, items = {}, alias = {} }
		R.SetPlayer(t, "Lee")
		return t.players.Kim ~= nil and t.players["Kim A"] ~= nil
	end)())

	-- Dalaran: boss NPC IDs unknown -> roll timing stays, the NPC is learned as the boss
	local ORB = "|cnIQ3:|Hitem:273052::::::::30:1490:::::::::|h[Schwerfällige Kugel]|h|r"
	clock = 60100
	R.OnEncounterEnd(dal, 3298, "Arkananomalie", 1)
	R.OnRollStart(dal, 902, ORB)
	R.OnLootWindow(dal, { { link = ORB, npc = 246020 } })
	check("Forever: unknown NPC in the loot window does not turn boss loot into trash", dal.items[2].source == 1 and dal.items[2].sure)
	check("Forever: NPC learned as that boss", ns.db.learnedNpc[246020] == "2959:ArcaneAnomaly")
	clock = 60300
	local ROBE = "|cnIQ3:|Hitem:273099::::::::30:1490:::::::::|h[Robe]|h|r"
	R.OnLootWindow(dal, { { link = ROBE, npc = 246020 } })
	R.OnLoot(dal, ns.Parse.Loot("Ihr erhaltet Beute: " .. ROBE), "Ibona Lightgrave")
	check("Forever: later own loot from that NPC = that boss (sure)", dal.items[3].source == 1 and dal.items[3].sure)
	R.OnLootWindow(dal, { { link = PERLE, npc = 999 } })
	R.OnLoot(dal, ns.Parse.Loot("Ihr erhaltet Beute: " .. PERLE), "Ibona Lightgrave")
	check("Forever: unknown NPC long after a kill = trash", dal.items[4].source == "trash")
	check("Dalaran: Mana Wraith optional, 7 required bosses", select(2, ns.Dungeons.WingProgress(ns.DUNGEONS[2959].wings[1], {})) == 0
		and select(3, ns.Dungeons.WingProgress(ns.DUNGEONS[2959].wings[1], {})) == 7)
	R.End("test")
	R.onComplete = nil
end

print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
