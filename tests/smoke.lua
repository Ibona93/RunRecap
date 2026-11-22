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
	if type(key) ~= "string" then return nil end
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
	check("Philosopher for headings, Noto Sans for text", F.PathFor("heading"):find("Philosopher") and F.PathFor("text"):find("NotoSans"))
	check("banner: Cinzel title, game font below", F.PathFor("banner"):find("Cinzel%-Bold") and F.PathFor("game") == "Fonts\\FRIZQT__.TTF"
		and F.BannerTitle(32) ~= F.BannerText(15))
	local old = ns.clientLocale
	ns.clientLocale = "zhCN"
	check("Chinese client uses the game font", not F.PathFor("heading"):find("Philosopher"))
	ns.clientLocale = "ruRU"
	check("Russian client: Philosopher (has Cyrillic), but game font for the banner title",
		F.PathFor("heading"):find("Philosopher") and not F.PathFor("banner"):find("Cinzel"))
	ns.clientLocale = old
end

print(failures == 0 and "\nall smoke checks passed" or ("\n" .. failures .. " smoke checks failed"))
os.exit(failures == 0 and 0 or 1)
