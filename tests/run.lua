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

print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
