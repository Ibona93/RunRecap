std = "lua51"
max_line_length = false
self = false
unused_args = false
globals = {
	"RunRecapDB", "SlashCmdList", "SLASH_RUNRECAP1",
}
read_globals = {
	"C_Timer", "CreateFrame", "CreateFont", "UIParent", "GameTooltip", "DEFAULT_CHAT_FRAME",
	"GetLocale", "GetBuildInfo", "InCombatLockdown", "IsShiftKeyDown",
	"GameFontHighlightSmall", "GameFontNormal", "STANDARD_TEXT_FONT", "unpack",
	"GetInstanceInfo", "GetNumLootItems", "GetLootSlotLink", "GetLootSourceInfo", "CombatLogGetCurrentEventInfo",
	"PlaySound", "GetTime", "date", "strsplit", "time",
	"UnitName", "UnitClass", "UnitExists", "UnitGUID", "UnitIsDeadOrGhost", "UnitIsFeignDeath", "GetPlayerInfoByGUID",
	"GetLootRollItemLink", "GetItemInfo", "GetItemIcon", "C_Item", "ITEM_QUALITY_COLORS", "RAID_CLASS_COLORS",
	"CreateColor", "Settings", "ChatEdit_InsertLink",
}

-- Test files mock the WoW API and set globals on purpose.
files["tests/"] = { std = "lua51", allow_defined_top = true, globals = { "_G" }, ignore = { "111", "112", "113", "121", "122", "142", "143", "211", "212", "213", "311", "411", "421", "431", "432" } }
