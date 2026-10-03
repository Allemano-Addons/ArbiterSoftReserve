std = "lua51"
max_line_length = false
exclude_files = { "Tests/", "Tools/alc_integration.lua" } -- the tests replace the game API on purpose
ignore = { "212/self", "212/_.*", "211", "311", "411", "421", "431" } -- style warnings: unused locals, shadowing

globals = { "ASR_DB", "SLASH_ARBITERSOFTRESERVE1", "SlashCmdList" }

read_globals = {
	"C_AddOns", "C_Timer", "GetAddOnMetadata", "CreateFrame", "DEFAULT_CHAT_FRAME", "UnitName", "ALC", "C_Item", "GetItemInfo", "GetItemIcon", "ITEM_QUALITY_COLORS", "strjoin", "tostringall", "time", "date",
	"UIParent", "UISpecialFrames", "ChatFontNormal", "GameFontHighlight", "RAID_CLASS_COLORS", "TooltipDataProcessor",
	"Enum", "GameTooltip", "ItemRefTooltip", "issecretvalue",
}
