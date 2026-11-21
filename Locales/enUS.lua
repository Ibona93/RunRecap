local _, ns = ...

-- English is the base and fallback for every UI string.
ns.RegisterLocale("enUS", {
	DEBUG_ON = "Debug output on.",
	DEBUG_OFF = "Debug output off.",
	NO_RECAP_YET = "No recap yet - the run overview arrives with version 0.1.",
	SLASH_HELP = "Commands: /recap (open the recap), /recap debug (debug output on/off), /recap help",
})
