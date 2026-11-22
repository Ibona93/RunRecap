--[[
Smoke test with a mocked WoW API (Lua 5.1). Run from the repository root:
    lua5.1 tests/smoke.lua
Loads every file from the TOC in order, fires the login events and runs the slash commands.
This catches runtime errors (nil calls, wrong fields) - it does NOT prove anything works or
looks right in the real client.
]]

local failures = 0
local function check(name, cond, detail)
	print((cond and "  ok   " or "  FAIL ") .. name .. ((not cond and detail) and ("  -> " .. tostring(detail)) or ""))
	if not cond then failures = failures + 1 end
end

-------------------------------------------------------------------------------
-- Generic frame mock: unknown methods are no-ops, the important ones are recorded.
-------------------------------------------------------------------------------

local eventFrames = {}
local Frame = {}

local function newFrame(kind, name)
	local f = { __kind = kind, __shown = true, __scripts = {}, __events = {} }
	setmetatable(f, Frame)
	if name then _G[name] = f end
	return f
end

Frame.__index = function(_, key)
	if type(key) ~= "string" or key:sub(1, 2) == "__" then return nil end
	if key == "SetScript" then return function(s, n, fn) s.__scripts[n] = fn end end
	if key == "GetScript" then return function(s, n) return s.__scripts[n] end end
	if key == "RegisterEvent" then
		return function(s, e) s.__events[e] = true eventFrames[s] = true end
	end
	if key == "UnregisterEvent" then return function(s, e) s.__events[e] = nil end end
	if key == "Show" then return function(s) s.__shown = true end end
	if key == "Hide" then return function(s) s.__shown = false end end
	if key == "IsShown" then return function(s) return s.__shown end end
	if key == "SetFont" then return function(s, path, size) s.__font = { path, size } return true end end
	if key == "CreateTexture" or key == "CreateFontString" or key == "CreateAnimationGroup" then
		return function(s) local c = newFrame(key) c.__parent = s return c end
	end
	if key == "SetText" then return function(s, t) s.__text = t end end
	if key == "GetText" then return function(s) return s.__text end end
	if key == "SetHeight" then return function(s, h) s.__h = h end end
	if key == "GetHeight" then return function(s) return s.__h or 20 end end
	if key == "SetWidth" then return function(s, w) s.__w = w end end
	if key == "GetWidth" then return function(s) return s.__w or 100 end end
	if key == "SetSize" then return function(s, w, h) s.__w, s.__h = w, h end end
	if key == "GetStringWidth" then return function(s) return #(s.__text or "") * 6 end end
	if key == "GetStringHeight" then return function() return 14 end end
	if key == "EnableMouse" then return function(s, v) s.__mouse = v or nil end end
	if key == "SetAlpha" then return function(s, a) s.__alpha = a end end
	if key == "GetAlpha" then return function(s) return s.__alpha or 1 end end
	if key == "SetChecked" then return function(s, v) s.__checked = v end end
	if key == "GetChecked" then return function(s) return s.__checked end end
	if key == "GetVerticalScrollRange" then return function() return 0 end end
	if key == "GetVerticalScroll" then return function() return 0 end end
	if key == "GetPoint" then return function() return "CENTER", nil, "CENTER", 12, 34 end end
	if key == "HookScript" then
		return function(s, n, fn)
			local old = s.__scripts[n]
			s.__scripts[n] = old and function(...) old(...) fn(...) end or fn
		end
	end
	if key == "GetFont" then
		return function(s)
			local f = rawget(s, "__font")
			if f then return f[1], f[2], "" end
			return "Fonts\\FRIZQT__.TTF", 12, ""
		end
	end
	return function() return nil end
end

_G.CreateFrame = function(kind, name) return newFrame(kind, name) end
_G.CreateFont = function(name) return newFrame("Font", name) end
_G.GameFontHighlightSmall = newFrame("Font")
_G.GameFontNormal = newFrame("Font")
_G.UIParent = newFrame("Frame")
local tip = { lines = {} }
_G.GameTooltip = setmetatable({}, { __index = function(_, k)
	if k == "SetOwner" or k == "ClearLines" then return function() tip.lines = {} end end
	if k == "SetText" or k == "AddLine" then return function(_, t) tip.lines[#tip.lines + 1] = tostring(t) end end
	if k == "AddDoubleLine" then return function(_, a, b) tip.lines[#tip.lines + 1] = tostring(a) .. " | " .. tostring(b) end end
	if k == "SetHyperlink" then return function(_, l) tip.lines[#tip.lines + 1] = "LINK " .. tostring(l) end end
	if k == "Show" then return function() tip.shown = true end end
	if k == "Hide" then return function() tip.shown = false end end
	return function() end
end })
local function tipHas(text)
	for _, l in ipairs(tip.lines) do if l:find(text, 1, true) then return true end end
	return false
end
local clock = 5000
_G.time = function() return clock end
local shiftDown, combat = false, false
_G.IsShiftKeyDown = function() return shiftDown end
_G.InCombatLockdown = function() return combat end
_G.RAID_CLASS_COLORS = { ROGUE = { r = 1, g = 0.96, b = 0.41, colorStr = "fffff569" } }
local unitNames = { player = "Ibona Hexfang", party1 = "Tarosh Dolchhieb" }
local deadUnits = {}
_G.UnitName = function(u) return unitNames[u] end
_G.UnitExists = function(u) return unitNames[u] ~= nil end
_G.UnitClass = function(u) if unitNames[u] then return "X", u == "player" and "WARLOCK" or "ROGUE" end end
_G.UnitIsDeadOrGhost = function(u) return deadUnits[u] or false end
_G.UnitGUID = function() return "Creature-0-6939-389-4711-11318-0000ABC" end
_G.GetPlayerInfoByGUID = function() return "Schurke", "ROGUE" end
_G.GetLootRollItemLink = function() return "|cnIQ3:|Hitem:272999::::::::13:1490::1:::::::|h[Barbarische Armbrust]|h|r" end
_G.GetItemIcon = function() return 134400 end

local chat = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) chat[#chat + 1] = msg end }
_G.GetLocale = function() return "deDE" end
_G.GetBuildInfo = function() return "1.60.1", "70707", "Nov 4 2026", 16001 end
_G.SlashCmdList = {}
_G.unpack = _G.unpack or table.unpack
_G.strsplit = function(sep, str)
	local out = {}
	for part in (str .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = part end
	return unpack(out)
end
_G.GetTime = function() return 1234.5 end
_G.GetInstanceInfo = function() return "The Deadmines", "party", 1, "Normal", 5, 0, false, 36 end
_G.GetNumLootItems = function() return 2 end
_G.GetLootSlotLink = function(slot) return slot == 1 and "|cff0070dd|Hitem:5191::::::::|h[Cruel Barb]|h|r" or nil end
_G.GetLootSourceInfo = function(slot) return "Creature-0-1-36-4-647-0000ABC", 1 end
local cleu = {}
_G.CombatLogGetCurrentEventInfo = function() return unpack(cleu) end
local played = {}
_G.PlaySound = function(id) played[#played + 1] = id return id ~= 17316 end
_G.C_Timer = { After = function(_, fn) fn() end }
_G.LOOT_ITEM = "%s receives loot: %s."

-------------------------------------------------------------------------------
-- Load the addon in TOC order
-------------------------------------------------------------------------------

local ns = {}
local loaded = 0
for line in io.lines("RunRecap.toc") do
	local file = line:match("^([%w_\\/]+%.lua)%s*$")
	if file then
		local path = file:gsub("\\", "/")
		local chunk, err = loadfile(path)
		check("load " .. path, chunk ~= nil, err)
		if chunk then
			local ok, runErr = pcall(chunk, "RunRecap", ns)
			check("run " .. path, ok, runErr)
			loaded = loaded + 1
		end
	end
end

-- Every .lua file in the addon folders must be listed in the TOC (catches forgotten entries).
do
	local listed = {}
	for line in io.lines("RunRecap.toc") do
		local file = line:match("^([%w_\\/]+%.lua)%s*$")
		if file then listed[(file:gsub("\\", "/"))] = true end
	end
	local missing = {}
	local p = io.popen('find . -name "*.lua" -not -path "./tests/*" -not -path "./.git/*" -not -name ".luacheckrc"')
	if p then
		for path in p:lines() do
			path = path:gsub("^%./", "")
			if not listed[path] then missing[#missing + 1] = path end
		end
		p:close()
	end
	check("every addon .lua file is in the TOC", #missing == 0, table.concat(missing, ", "))
end

local function fire(event, ...)
	for f in pairs(eventFrames) do
		if f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
	end
end

print("Events")
local ok, err = pcall(fire, "ADDON_LOADED", "SomeOtherAddon")
check("ADDON_LOADED of another addon is ignored", ok and _G.RunRecapDB == nil, err)
ok, err = pcall(fire, "ADDON_LOADED", "RunRecap")
check("ADDON_LOADED creates the saved variables", ok and type(_G.RunRecapDB) == "table" and ns.db == _G.RunRecapDB, err)

print("Version")
do
	local tocVersion
	for line in io.lines("RunRecap.toc") do tocVersion = tocVersion or line:match("^## Version:%s*(%S+)") end
	check("TOC version matches ns.VERSION", tocVersion == ns.VERSION, tostring(tocVersion) .. " vs " .. tostring(ns.VERSION))
end

print("Slash command")
check("/recap is registered", _G.SLASH_RUNRECAP1 == "/recap" and type(SlashCmdList.RUNRECAP) == "function")
for _, cmd in ipairs({ "", "help", "debug", "debug", "  HELP  " }) do
	chat = {}
	ok, err = pcall(SlashCmdList.RUNRECAP, cmd)
	check(("/recap %q runs and prints"):format(cmd), ok and #chat > 0, err)
end
check("/recap debug toggles twice back to off", ns.db.debug == false)

print("Probe")
do
	local P = ns.Probe
	check("GUID shortened to NPC ID", P.ShortGUID("Creature-0-1-36-4-647-0000ABC") == "Creature npc=647")
	chat = {}
	ok, err = pcall(SlashCmdList.RUNRECAP, "probe")
	check("/recap probe starts recording", ok and ns.db.probeActive == true and #ns.db.probe > 5, err)
	local function has(pattern)
		for _, line in ipairs(ns.db.probe) do if line:find(pattern) then return true end end
		return false
	end
	check("start snapshot: client, API list, global strings, instance", has("START | client 1.60.1") and has("GetLootSourceInfo=yes")
		and has('LOOT_ITEM = "%%s receives loot') and has("LOOT_ROLL_WON = MISSING") and has('"The Deadmines"'))
	ok, err = pcall(fire, "ENCOUNTER_END", 1144, "Edwin VanCleef", 1, 5, 1)
	check("ENCOUNTER_END recorded with instance info", ok and has('ENCOUNTER_END | 1144, "Edwin VanCleef", 1, 5, 1 | instance: "The Deadmines"'), err)
	ok, err = pcall(fire, "LOOT_OPENED")
	check("loot window: slot link and source NPC", ok and has("LOOT_SLOT | 1 .*Cruel Barb.*<%- Creature npc=647 x1")
		and has("LOOT_SLOT | 2 %(money/no link%)"), err)
	ok, err = pcall(fire, "CHAT_MSG_LOOT", "Kesh receives loot: [Cruel Barb].")
	check("CHAT_MSG_LOOT recorded", ok and has("CHAT_MSG_LOOT | \"Kesh receives loot"), err)
	cleu = { 1, "UNIT_DIED", false, nil, nil, 0, 0, "Player-1-ABC", "Mirela", 1297 }
	ok, err = pcall(fire, "COMBAT_LOG_EVENT_UNFILTERED")
	cleu = { 1, "SPELL_DAMAGE", false, nil, nil, 0, 0, "Player-1-ABC", "Mirela", 1297 }
	pcall(fire, "COMBAT_LOG_EVENT_UNFILTERED")
	check("combat log: deaths recorded, other events ignored", ok and has('CLEU | "UNIT_DIED", "Mirela", "Player"')
		and not has("SPELL_DAMAGE"), err)
	ns.Probe.Resume()
	check("resume after /reload keeps recording", has("RESUME"))
	played = {}
	ok, err = pcall(SlashCmdList.RUNRECAP, "sounds")
	check("/recap sounds plays every candidate", ok and #played == #P.SOUNDS, err)
	check("... and reports missing sounds", has("SOUND | 17316 missing") and has("SOUND | 888 plays"))
	played = {}
	ok, err = pcall(SlashCmdList.RUNRECAP, "sound 878")
	check("/recap sound 878 plays that ID", ok and played[1] == 878, err)
	ok, err = pcall(SlashCmdList.RUNRECAP, "probe")
	check("/recap probe again stops", ok and ns.db.probeActive == false and has("STOP"), err)
	local n = #ns.db.probe
	pcall(fire, "CHAT_MSG_LOOT", "after stop")
	check("nothing recorded after stop", #ns.db.probe == n)
	pcall(SlashCmdList.RUNRECAP, "probe clear")
	check("/recap probe clear empties the log", #ns.db.probe == 0)
end

print("Fonts")
do
	local F = ns.Fonts
	local h, t = F.Heading(16), F.Text(12)
	check("heading and text font objects are created", h and t and h ~= t)
	check("font objects are cached", F.Heading(16) == h)
	check("headings and text use the game font (native look)", F.PathFor("heading") == "Fonts\\FRIZQT__.TTF" and F.PathFor("text") == "Fonts\\FRIZQT__.TTF")
	check("banner: Cinzel title, game font below", F.PathFor("banner"):find("Cinzel%-Bold") and F.PathFor("game") == "Fonts\\FRIZQT__.TTF"
		and F.BannerTitle(32) ~= F.BannerText(15))
	local old = ns.clientLocale
	ns.clientLocale = "zhCN"
	check("Chinese client uses the game font, also for the banner", not F.PathFor("banner"):find("Cinzel"))
	ns.clientLocale = "ruRU"
	check("Russian client: game font for the banner title (Cinzel has no Cyrillic)",
		not F.PathFor("banner"):find("Cinzel"))
	ns.clientLocale = old
end


print("Run in the game (simulated events)")
do
	for k, v in pairs({
		LOOT_ITEM = "%s bekommt Beute: %s.", LOOT_ITEM_SELF = "Ihr erhaltet Beute: %s",
		LOOT_ROLL_WON = "|HlootHistory:%d|h[Beute]|h: Gewonnen von %s: %s",
		LOOT_ROLL_ROLLED_GREED = "|HlootHistory:%d|h[Beute]|h: Wurf für Gold: %d für %s von %s",
		LOOT_ROLL_PASSED = "|HlootHistory:%d|h[Beute]|h: Weitergegeben von %s: %s",
		LOOT_MONEY_SPLIT = "Euer Anteil an der Beute ist %s.", COPPER_AMOUNT = "%d Kupfer", SILVER_AMOUNT = "%d Silber",
		INSTANCE_RESET_SUCCESS = "%s wurde zurückgesetzt.",
	}) do _G[k] = v end
	local ARMBRUST = "|cnIQ3:|Hitem:272999::::::::13:1490::1:::::::|h[Barbarische Armbrust]|h|r"
	local PERLE = "|cnIQ2:|Hitem:5498::::::::13:1490:::::::::|h[Kleine irisierende Perle]|h|r"
	ns.db.currentRun, ns.db.runs = nil, {}
	ok, err = pcall(fire, "PLAYER_LOGIN")
	check("PLAYER_LOGIN builds the options (fallback window without Settings)", ok and ns.Options.Panel() ~= nil, err)

	_G.GetInstanceInfo = function() return "Ragefireabgrund", "party", 1, "Normal", 5, 0, false, 389 end
	ok, err = pcall(fire, "PLAYER_ENTERING_WORLD", true, false)
	local run = ns.db.currentRun
	check("entering Ragefire starts a run with the group", ok and run and run.mapID == 389 and run.players["Tarosh Dolchhieb"] == "ROGUE", err)
	pcall(fire, "PLAYER_TARGET_CHANGED")
	check("target GUID remembers the instance copy", run.zoneUID == "4711")

	clock = 5100
	pcall(fire, "ENCOUNTER_START", 2732, "Flintauge", 1, 5)
	clock = 5140
	ok, err = pcall(fire, "ENCOUNTER_END", 2732, "Flintauge", 1, 5, 1)
	check("ENCOUNTER_END records the kill", ok and #run.kills == 1 and run.kills[1].fight == 40, err)
	clock = 5141
	ok, err = pcall(fire, "START_LOOT_ROLL", 12, 180000, 4470529)
	check("START_LOOT_ROLL creates the boss drop", ok and #run.items == 1 and run.items[1].rolling and run.items[1].source == 1, err)
	local H = "|HlootHistory:4470529|h[Beute]|h: "
	pcall(fire, "CHAT_MSG_LOOT", H .. "Wurf für Gold: 88 für " .. ARMBRUST .. " von Tarosh Dolchhieb", "")
	pcall(fire, "CHAT_MSG_LOOT", H .. "Gewonnen von Tarosh Dolchhieb: " .. ARMBRUST, "")
	pcall(fire, "LOOT_ROLLS_COMPLETE", 4470529)
	ok, err = pcall(fire, "CHAT_MSG_LOOT", "Tarosh Dolchhieb bekommt Beute: " .. ARMBRUST .. ".", "Tarosh Dolchhieb", "", "", "", "", 0, 0, "", 0, 1, "Player-1-2")
	check("roll and loot lines: won by Tarosh, no duplicate", ok and #run.items == 1 and run.items[1].looter == "Tarosh Dolchhieb"
		and run.items[1].rolls["Tarosh Dolchhieb"].value == 88, err)
	pcall(fire, "CHAT_MSG_LOOT", "Tarosh Dolchhieb bekommt Beute: " .. PERLE .. ".", "Tarosh Dolchhieb")
	pcall(fire, "CHAT_MSG_MONEY", "Euer Anteil an der Beute ist 1 Silber, 13 Kupfer.")
	check("green direct loot and gold", #run.items == 2 and run.money == 113)
	_G.GetNumLootItems = function() return 1 end
	_G.GetLootSlotLink = function() return PERLE end
	_G.GetLootSourceInfo = function() return "Creature-0-6939-389-4711-11517-0000ABC", 1 end
	ok, err = pcall(fire, "LOOT_OPENED")
	check("own loot window is read", ok and run.loot and run.loot[5498] and run.loot[5498].npc == 11517, err)

	deadUnits.party1 = true
	pcall(fire, "UNIT_HEALTH", "party1")
	pcall(fire, "UNIT_FLAGS", "party1")
	check("party member death counted once", run.deaths["Tarosh Dolchhieb"] == 1)
	deadUnits.party1 = nil
	pcall(fire, "UNIT_HEALTH", "party1")

	clock = 5300
	pcall(fire, "ENCOUNTER_END", 2733, "Taragaman der Hungerleider", 1, 5, 1)
	pcall(fire, "ENCOUNTER_END", 2735, "Bazzalan", 1, 5, 1)
	combat = true
	played = {}
	clock = 5400
	ok, err = pcall(fire, "ENCOUNTER_END", 2734, "Jergosh der Herbeirufer", 1, 5, 1)
	local banner = _G.RunRecapBanner
	check("last boss: completed, sound 878, banner shown", ok and run.completed and played[1] == 878 and banner and banner:IsShown(), err)
	check("banner text: title, dungeon, status line", banner.Title.__text == ns.L.BANNER_TITLE and banner.Name.__text == "Ragefireabgrund"
		and banner.Status.__text:find("4/4") ~= nil)
	local onUpdate = banner.__scripts.OnUpdate
	local okU, errU = pcall(onUpdate, banner, 1)
	check("banner fades in, ignores the mouse in combat", banner.__alpha == 1 and rawget(banner, "__mouse") == nil)
	pcall(onUpdate, banner, 4)
	check("after ~4 s the banner is gone; recap waits for the end of combat", not banner:IsShown() and not ns.Recap.IsShown())
	combat = false
	ok, err = pcall(fire, "PLAYER_REGEN_ENABLED")
	check("end of combat opens the recap", ok and ns.Recap.IsShown(), err)
	local f = ns.Recap.Frame()
	check("recap uses Blizzard's window template", f.template == "ButtonFrameTemplate")
	check("recap header: dungeon and state", f.Dungeon.__text == "Ragefireabgrund" and f.Sub.__text:find(ns.L.COMPLETED, 1, true) ~= nil)

	-- find rendered rows by content
	local function findRow(pred)
		for _, child in pairs(eventFrames) do local _ = child end
		return nil
	end
	local _ = findRow
	ok, err = pcall(ns.Recap.Render)
	check("render runs", ok, err)

	-- tooltips: boss row, item name, rolls (with Shift)
	local s = ns.Run.Summary(run, false)
	ok, err = pcall(ns.Recap.BossTooltip, f, run, s.bosses[1])
	check("boss tooltip: name and kill time", ok and tipHas("Flintauge") and tipHas("0:40"), err)
	shiftDown = true
	pcall(ns.Recap.BossTooltip, f, run, s.bosses[1])
	check("boss tooltip with Shift: wipes, deaths, items", tipHas("Wipes an diesem Boss: 0") and tipHas(ns.L.TT_NO_DEATHS) and tipHas("Items: 1"))
	ok, err = pcall(ns.Recap.ItemTooltip, f, run, run.items[1])
	check("item tooltip: Blizzard link + looter + source", ok and tipHas("LINK |cnIQ3") and tipHas("Geplündert von Tarosh Dolchhieb")
		and tipHas("Quelle: Flintauge"), err)
	ok, err = pcall(ns.Recap.RollTooltip, f, run, run.items[1])
	check("roll tooltip with Shift: winner and all rolls", ok and tipHas("hat gewonnen - Gier 88") and tipHas("Gier 88"), err)
	shiftDown = false
	pcall(ns.Recap.RollTooltip, f, run, run.items[2])
	check("roll tooltip of direct loot", tipHas(ns.L.DIRECT_LOOT))
	pcall(ns.Recap.ItemTooltip, f, run, run.items[2])
	check("unsure item: 'probably' + explanation", tipHas("(vermutlich)") and tipHas("Lootfenster"))

	-- /recap toggles; options; preview
	chat = {}
	pcall(SlashCmdList.RUNRECAP, "")
	check("/recap closes the open recap", not ns.Recap.IsShown())
	pcall(SlashCmdList.RUNRECAP, "")
	check("/recap opens the last recap", ns.Recap.IsShown())
	ok, err = pcall(SlashCmdList.RUNRECAP, "options")
	check("/recap options opens the options window", ok and _G.RunRecapOptionsWindow and _G.RunRecapOptionsWindow:IsShown(), err)
	ns.db.showGreen = true
	ok, err = pcall(ns.Recap.Render)
	check("render with green items", ok, err)
	ns.db.showGreen = false

	-- leave alive, reset -> run kept in history (completed)
	_G.GetInstanceInfo = function() return "Orgrimmar", "none", 0, "", 0, 0, false, 1 end
	pcall(fire, "ZONE_CHANGED_NEW_AREA")
	check("leaving alive pauses the run", run.state == "paused")
	ok, err = pcall(fire, "CHAT_MSG_SYSTEM", "Ragefireabgrund wurde zurückgesetzt.")
	check("instance reset ends it; completed run kept", ok and ns.db.currentRun == nil and ns.db.runs[#ns.db.runs] == run, err)

	played = {}
	ok, err = pcall(SlashCmdList.RUNRECAP, "demo")
	check("/recap demo: sound + banner of the preview run", ok and played[1] == 878 and _G.RunRecapBanner:IsShown(), err)
	pcall(ns.Banner.Finish)
	check("click/finish opens the preview recap; nothing saved", ns.Recap.IsShown() and ns.Recap.Frame().run.demo and ns.db.currentRun == nil)
	ns.db.sound = 0
	played = {}
	ns.db.autoOpen = false
	chat = {}
	ns.Banner.Celebrate(ns.Demo.Run())
	check("sound off + auto open off: no sound, only a chat line", #played == 0 and #chat == 1)
	ns.db.sound, ns.db.autoOpen = 878, true
	check("options: sound names", ns.Options.SoundName(878) == "Quest abgeschlossen" and ns.Options.SoundName(0) == "Aus")
	check("every event handler registered", #ns.EVENTS >= 20)
end

print(failures == 0 and "\nall smoke checks passed" or ("\n" .. failures .. " smoke checks failed"))
os.exit(failures == 0 and 0 or 1)
