-- Run Recap Forever: namespace and shared helpers.
-- Loaded first; every other file receives the same private namespace table `ns`.
local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.VERSION = "1.0.0"
ns.ICON = "Interface\\AddOns\\RunRecap\\Media\\Icon" -- addon icon (minimap button, window portrait)

-- Locale registry, filled by Locales/*.lua.
ns.Locales = {}           -- [locale] = { KEY = "UI string" }

function ns.RegisterLocale(locale, strings)
	ns.Locales[locale] = strings
end

-- The ten languages the addon ships texts for. enGB/esMX/ptPT are mapped in NormalizeLocale.
ns.LANGUAGES = { "enUS", "deDE", "frFR", "esES", "ptBR", "itIT", "ruRU", "koKR", "zhCN", "zhTW" }

function ns.NormalizeLocale(locale)
	if locale == "enGB" then return "enUS" end
	if locale == "esMX" then return "esES" end
	if locale == "ptPT" then return "ptBR" end
	return locale
end

-- Calls a function only if it exists; never raises. Returns the function's results or nil.
--[[
Secret values (Forever, like Retail): in instances the client hands out some values sealed -
GUIDs of nameplates/targets in combat, some chat lines. Touching them (compare, strsplit,
match) is blocked and lands in the taint log (Kral, 24.11.2026: ~16,000 entries). Every value
from a unit function or an event goes through ns.Plain first: sealed -> nil, skipped.
]]
function ns.IsSecret(v)
	local issecret = _G.issecretvalue
	return issecret ~= nil and v ~= nil and issecret(v) == true
end

function ns.Plain(v)
	if ns.IsSecret(v) then return nil end
	return v
end

function ns.TryCall(fn, ...)
	if type(fn) ~= "function" then return nil end
	local results = { pcall(fn, ...) }
	if not results[1] then
		ns.Debug("call failed: " .. tostring(results[2]))
		return nil
	end
	return select(2, unpack(results))
end

local debugLog = {}
ns.debugLog = debugLog

function ns.Debug(msg)
	debugLog[#debugLog + 1] = msg
	if #debugLog > 200 then table.remove(debugLog, 1) end
	if ns.db and ns.db.debug and DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff7fbfffRun Recap debug:|r " .. tostring(msg))
	end
end

function ns.Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Run Recap:|r " .. tostring(msg))
	end
end

function ns.CopyTable(src)
	if type(src) ~= "table" then return src end
	local out = {}
	for k, v in pairs(src) do out[k] = ns.CopyTable(v) end
	return out
end

-- Fills missing keys of `target` from `defaults` (recursively), keeps user values.
function ns.MergeDefaults(target, defaults)
	for k, v in pairs(defaults) do
		if target[k] == nil then
			target[k] = ns.CopyTable(v)
		elseif type(v) == "table" and type(target[k]) == "table" then
			ns.MergeDefaults(target[k], v)
		end
	end
	return target
end
