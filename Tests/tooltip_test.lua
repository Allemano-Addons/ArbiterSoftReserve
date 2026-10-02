-- Offline test of SoftRes/Tooltip.lua (the text of the tooltip line) and Commands.lua (/asr).
-- Run from the ArbiterSoftReserve folder:  lua Tests/tooltip_test.lua
time = os.time -- the game's global

local failed = 0
local function check(name, ok)
	if not ok then
		failed = failed + 1
		print("FAIL: " .. name)
	end
end

local ASR = { db = {} }
local printed = {}
function ASR:Print(...) printed[#printed + 1] = table.concat({ ... }, " ") end
assert(loadfile("SoftRes/Import.lua"))("ArbiterSoftReserve", ASR)
assert(loadfile("SoftRes/Rules.lua"))("ArbiterSoftReserve", ASR)
assert(loadfile("SoftRes/Tooltip.lua"))("ArbiterSoftReserve", ASR)
local SoftRes = ASR.SoftRes

check("no list: no line", SoftRes.TooltipText(29764) == nil)

local csv = table.concat({
	"Item Name,Item ID,From,Raider Name,Raider Class,Raider Spec,Raider Note,Extra Reserves,Date",
	"Pauldrons,29764,Maulgar,Allemano,Druid,Balance,,0,x",
	"Pauldrons,29764,Maulgar,Erikdbest,Warrior,Fury,,0,x",
	"Trophy,28830,Gruul,Erikdbest,Death Knight,Fury,,0,x",
}, "\n")
SoftRes:Import(csv)

check("the names of those who reserved it", SoftRes.TooltipText(29764) == "Soft reserved by: Allemano, Erikdbest")
check("an item nobody reserved has no line", SoftRes.TooltipText(11111) == nil)
local colors = { DRUID = "ff7d0a", WARRIOR = "c69b6d", DEATHKNIGHT = "c41e3a" }
check("the names get the colour of their class", SoftRes.TooltipText(29764, colors) == "Soft reserved by: |cffff7d0aAllemano|r, |cffc69b6dErikdbest|r")
check("a class with two words finds its colour", SoftRes.TooltipText(28830, colors) == "Soft reserved by: |cffc41e3aErikdbest|r")
check("an unknown class is not coloured", SoftRes.TooltipText(28830, { DRUID = "ff7d0a" }) == "Soft reserved by: Erikdbest")

-- many reservers
local lines = { "Item ID,Raider Name,Raider Class" }
for i = 1, 9 do lines[#lines + 1] = "500,Player" .. i .. ",Mage" end
SoftRes:Import(table.concat(lines, "\n"))
check("a long list is cut with a count", SoftRes.TooltipText(500) == "Soft reserved by: Player1, Player2, Player3, Player4, Player5, Player6 (+3 more)")

-- installing outside the game does nothing, and twice is safe
check("the tooltip can be installed without a game", pcall(SoftRes.InstallTooltip) and pcall(SoftRes.InstallTooltip))

-- /asr
assert(loadfile("Commands.lua"))("ArbiterSoftReserve", ASR)
ASR.ImportWindow = { Show = function() ASR.shown = true end }
ASR.version = "0.1.0"
SoftRes:Clear()

printed = {}
ASR.Commands.Run("")
check("/asr without a list says how to import", printed[1]:find("0.1.0", 1, true) and printed[2]:find("/asr import", 1, true))
ASR.Commands.Run("import")
check("/asr import opens the box", ASR.shown == true)
SoftRes:Import(csv)
printed = {}
ASR.Commands.Run("")
check("/asr says what is loaded", printed[2]:find("3 reservations from 2 players", 1, true) and printed[2]:find(" show ", 1, true))
ASR.Commands.Run("tooltip off")
check("/asr tooltip off is remembered", ASR.db.tooltip == false)
printed = {}
ASR.Commands.Run("")
check("and shown in the status", printed[2]:find("do not show", 1, true) ~= nil)
ASR.Commands.Run("TOOLTIP On")
check("/asr tooltip on", ASR.db.tooltip == true)
printed = {}
ASR.Commands.Run("tooltip maybe")
check("a wrong tooltip argument gets the usage", printed[1]:find("Usage", 1, true) ~= nil)
SoftRes:Clear()
UnitName = function() return "Me" end
printed = {}
ASR.Commands.Run("add |cffa335ee|Hitem:28830::::::::70:::::|h[Dragonspine Trophy]|h|r Erik")
check("/asr add takes an item link and a name", SoftRes:IsReserver("Erik", 28830) and printed[1]:find("Added item 28830 for Erik", 1, true))
ASR.Commands.Run("add 29764")
check("the name defaults to you", SoftRes:IsReserver("Me", 29764))
printed = {}
ASR.Commands.Run("add nonsense")
check("/asr add without an item gets the usage", printed[1]:find("Usage", 1, true) ~= nil)
SoftRes:Clear()
ASR.Commands.Run("add |Hitem:273647::::::::70:::::|h[Worgpelt Leggings]|h Allemano Moo")
check("a link without colour codes does not leak into the name", SoftRes:IsReserver("Allemano Moo", 273647) and #SoftRes:GetReservers(273647) == 1
	and SoftRes:GetReservers(273647)[1].name == "Allemano Moo")
ASR.Commands.Run("add 555 [Plain Text Name] Bob")
check("a bracketed name is dropped too", SoftRes:GetReservers(555)[1] and SoftRes:GetReservers(555)[1].name == "Bob")
SoftRes:Clear()
ASR.Commands.Run("add |cnIQ3:|Hitem:273647::::::::70:::::|h[Worgpelt Leggings]|h|r")
check("a modern colour code does not leak into the name", #SoftRes:GetReservers(273647) == 1 and SoftRes:GetReservers(273647)[1].name == "Me")
ASR.Commands.Run("add |cnIQ3:|Hitem:273648::::::::70:::::|h[X]|h|r Allemano")
check("and a name after it still works", SoftRes:GetReservers(273648)[1] and SoftRes:GetReservers(273648)[1].name == "Allemano")
SoftRes:Import("Item ID,Raider Name\n9,|cnIQ3:Dirty|r Name")
check("a dirty name in a CSV is cleaned", SoftRes:GetReservers(9)[1] and SoftRes:GetReservers(9)[1].name == "Dirty Name")
ASR.Commands.Run("clear")
check("/asr clear forgets the list", SoftRes:GetList() == nil)
printed = {}
ASR.Commands.Run("whatever")
check("an unknown command lists the commands", #printed >= 4 and printed[1] == "Commands:")

if failed > 0 then
	print(failed .. " failed")
	os.exit(1)
end
print("ALL OK")
