-- Offline test of SoftRes/Import.lua (the softres.it CSV). Run from the ArbiterSoftReserve folder:  lua Tests/import_test.lua
time = os.time -- the game's global

local failed = 0
local function check(name, ok)
	if not ok then
		failed = failed + 1
		print("FAIL: " .. name)
	end
end

local ASR = {}
assert(loadfile("SoftRes/Import.lua"))("ArbiterSoftReserve", ASR)
local SoftRes = ASR.SoftRes

local csv = table.concat({
	"Item Name,Item ID,From,Raider Name,Raider Class,Raider Spec,Raider Note,Extra Reserves,Date",
	"Pauldrons of the Fallen Defender,29764,High King Maulgar,Allemano,Druid,Balance,,0,2026-10-01 20:44:11",
	"Pauldrons of the Fallen Defender,29764,High King Maulgar,Erikdbest,Warrior,Fury,,0,2026-10-01 20:44:52",
	"Dragonspine Trophy,28830,Gruul the Dragonkiller,Erikdbest,Warrior,Fury,,0,2026-10-01 20:44:52",
	"Hammer of the Naaru,28800,High King Maulgar,Gavztahx,Paladin,Protection,,0,2026-10-01 20:44:30",
	"Pauldrons of the Fallen Champion,29763,High King Maulgar,Gavztahx,Paladin,Protection,,0,2026-10-01 20:44:30",
}, "\n")

local parsed = SoftRes.ParseCSV(csv)
check("the export is read", parsed ~= nil and parsed.rows == 5 and parsed.players == 3 and parsed.skipped == 0)
check("two players reserved the same item", #parsed.reserves[29764] == 2 and parsed.reserves[29764][1].name == "Allemano")
check("with class and spec", parsed.reserves[29764][2].class == "Warrior" and parsed.reserves[29764][2].spec == "Fury")
check("one player, two items", parsed.reserves[28830][1].name == "Erikdbest" and parsed.reserves[29764][2].name == "Erikdbest")

check("windows line endings work", SoftRes.ParseCSV((csv:gsub("\n", "\r\n"))).rows == 5)
check("a byte order mark at the start is ignored", SoftRes.ParseCSV("\239\187\191" .. csv).rows == 5)
local quoted = 'Item Name,Item ID,From,Raider Name,Raider Class,Raider Spec,Raider Note,Extra Reserves,Date\n"Boots, Odd ""Name""",100,Boss,Veyra,Priest,Holy,"rolls late, sorry",1,2026-10-01'
local q = SoftRes.ParseCSV(quoted)
check("quoted fields with commas and quotes", q and q.reserves[100][1].name == "Veyra" and q.reserves[100][1].note == "rolls late, sorry" and q.reserves[100][1].extra == 1)
local bad = SoftRes.ParseCSV(csv .. "\nSomething,notanumber,Boss,Kaelis,Hunter,BM,,0,x\nNothing,555,Boss,,Hunter,BM,,0,x")
check("bad lines are skipped and counted", bad and bad.rows == 5 and bad.skipped == 2)
local columns = SoftRes.ParseCSV("Raider Name,Item ID\nVeyra,200")
check("only the two needed columns are needed, in any order", columns and columns.reserves[200][1].name == "Veyra")
local no, message = SoftRes.ParseCSV("hello world")
check("something else is refused with a message", no == nil and message ~= nil)
check("an empty text is refused", SoftRes.ParseCSV("") == nil and SoftRes.ParseCSV(nil) == nil)
check("a header alone has no reservations", SoftRes.ParseCSV("Item ID,Raider Name\n") == nil)

-- The loaded list, kept in the saved variables
ASR.db = {}
check("nothing is loaded at first", SoftRes:GetList() == nil)
local list = SoftRes:Import(csv)
check("the list is imported and remembered", list ~= nil and SoftRes:GetList() == list and list.importedAt ~= nil)
check("and saved", ASR.db.softres == list)
check("who reserved an item", #SoftRes:GetReservers(29764) == 2 and #SoftRes:GetReservers(99999) == 0)
check("a first name matches the character with a surname", SoftRes:IsReserver("Allemano Moo", 29764) and SoftRes:IsReserver("allemano", 29764))
check("somebody who did not reserve it is not a reserver", not SoftRes:IsReserver("Kaelis Moo", 29764))
check("names are not matched by their beginning", not SoftRes:IsReserver("Allemanoo Moo", 29764))
SoftRes:Clear()
check("the list can be cleared", SoftRes:GetList() == nil and ASR.db.softres == nil)

-- After a reload the saved list is found again
ASR.db = { softres = parsed }
local ASR2 = { db = ASR.db }
assert(loadfile("SoftRes/Import.lua"))("ArbiterSoftReserve", ASR2)
check("a saved list is found after a reload", ASR2.SoftRes:GetList() == parsed and ASR2.SoftRes:IsReserver("Erikdbest Moo", 28830))


-- The loaded list as text again (to edit in the box), and one reservation added by hand
local ASR3 = {}
assert(loadfile("SoftRes/Import.lua"))("ArbiterSoftReserve", ASR3)
ASR3.SoftRes:Import(csv)
local round = SoftRes.ParseCSV(ASR3.SoftRes:ToCSV())
check("the list written as CSV reads back the same", round ~= nil and round.rows == 5 and round.players == 3
	and round.reserves[29764][2].name == "Erikdbest" and round.reserves[29764][2].class == "Warrior")
check("an empty list is empty text", SoftRes.ToCSV({ GetList = function() return nil end }) == "")
check("a name with a comma survives", (function()
	local x = {}
	assert(loadfile("SoftRes/Import.lua"))("ArbiterSoftReserve", x)
	x.SoftRes:Import("Item ID,Raider Name\n1,\"Doe, Jane\"")
	local back = SoftRes.ParseCSV(x.SoftRes:ToCSV())
	return back and back.reserves[1][1].name == "Doe, Jane"
end)())
local added = ASR3.SoftRes:Add(12345, "Allemano")
check("one reservation can be added", added and added.rows == 6 and ASR3.SoftRes:IsReserver("Allemano", 12345))
check("the old ones are still there", ASR3.SoftRes:IsReserver("Gavztahx", 28800))
local fresh = {}
assert(loadfile("SoftRes/Import.lua"))("ArbiterSoftReserve", fresh)
check("adding starts a list when there is none", fresh.SoftRes:Add(7, "Solo") and fresh.SoftRes:GetList().rows == 1)
check("a bad item is refused", select(2, fresh.SoftRes:Add("x", "Solo")) ~= nil and select(2, fresh.SoftRes:Add(7, "")) ~= nil)
-- The class of a character, for colouring names
do
	SoftRes:Import("Item Name,Item ID,From,Raider Name,Raider Class,Raider Spec,Raider Note,Extra Reserves,Date\n,29764,,Allemano,Death Knight,Frost,,0,x")
	check("a class from the list is a token", SoftRes.ClassOf("Allemano Moo", 29764) == "DEATHKNIGHT")
	check("an unknown player or item has no class", SoftRes.ClassOf("Nobody", 29764) == nil and SoftRes.ClassOf("Allemano", 1) == nil and SoftRes.ClassOf("", 29764) == nil and SoftRes.ClassOf(nil, 1) == nil)
	local realFind, realClass = ALC, UnitClass
	ALC = { FindUnitByName = function(_, name) if name == "Veyra Moo" then return "party1" end end }
	UnitClass = function(unit) if unit == "party1" then return "Warrior", "WARRIOR" end end
	check("a player in the group is read from the game first", SoftRes.ClassOf("Veyra Moo", 29764) == "WARRIOR")
	check("and the list is the fallback", SoftRes.ClassOf("Allemano Moo", 29764) == "DEATHKNIGHT")
	ALC, UnitClass = realFind, realClass
end

if failed > 0 then
	print(failed .. " failed")
	os.exit(1)
end
print("ALL OK")
