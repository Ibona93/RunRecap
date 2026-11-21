local ADDON_NAME, ns = ...

--[[
Core: saved settings, locale, events and the slash command.
Run detection, loot and the recap window follow with version 0.1 (see the concept doc).
]]

ns.DEFAULTS = {
	schema = 1,
	debug = false,
	runs = {},              -- finished runs (newest last); filled from 0.1 on
	currentRun = nil,       -- the run in progress, saved continuously so /reload loses nothing
	probeActive = false,    -- developer probe (/recap probe) is recording
	probe = {},             -- developer probe log lines
	ej = nil,               -- developer dump of the Adventure Guide (/recap ej)
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
-- Events
-------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
ns.eventFrame = frame

frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			ns.InitDB()
			if ns.Probe then ns.Probe.Resume() end
			frame:UnregisterEvent("ADDON_LOADED")
		end
	end
end)

for _, event in ipairs({ "ADDON_LOADED" }) do
	pcall(frame.RegisterEvent, frame, event)
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
		end
	elseif msg == "help" or msg == "?" then
		ns.Print(L.SLASH_HELP)
	else
		-- The recap window comes with 0.1; until then /recap explains itself.
		ns.Print(L.NO_RECAP_YET)
		ns.Print(L.SLASH_HELP)
	end
end
