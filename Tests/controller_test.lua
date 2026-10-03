-- Offline test of SoftRes/Controller.lua (the session the window shows). Run from the ArbiterSoftReserve folder:
--   lua Tests/controller_test.lua
time = os.time -- the game's global

local failed = 0
local function check(name, ok)
	if not ok then
		failed = failed + 1
		print("FAIL: " .. name)
	end
end

local ASR = { db = {} }
for _, file in ipairs({ "Import", "Rules", "Session", "Controller" }) do
	assert(loadfile("SoftRes/" .. file .. ".lua"))("ArbiterSoftReserve", ASR)
end
local SoftRes = ASR.SoftRes
local Controller = SoftRes.Controller

-- Item IDs from a command line
local ids = Controller.ParseItemIDs("|cnIQ3:|Hitem:273647::::::::70:::::|h[Worgpelt Leggings]|h|r |Hitem:29764:|h[X]|h")
check("links give item IDs", #ids == 2 and ids[1] == 273647 and ids[2] == 29764)
ids = Controller.ParseItemIDs("29764 28830, 28800")
check("plain numbers work too", #ids == 3 and ids[3] == 28800)
check("nothing gives nothing", #Controller.ParseItemIDs("") == 0 and #Controller.ParseItemIDs(nil) == 0)

-- No list: nothing to take items from
check("without a list there are no items", #Controller.ItemsOfList() == 0)

SoftRes:Import(table.concat({
	"Item Name,Item ID,From,Raider Name,Raider Class,Raider Spec,Raider Note,Extra Reserves,Date",
	"Pauldrons,29764,Maulgar,Allemano,Druid,Balance,,0,x",
	"Pauldrons,29764,Maulgar,Erikdbest,Warrior,Fury,,0,x",
	"Trinket,28830,Gruul,Erikdbest,Warrior,Fury,,0,x",
}, "\n"))
ids = Controller.ItemsOfList()
check("the list gives its items, the first with two reservers twice", #ids == 3 and ids[1] == 28830 and ids[2] == 29764 and ids[3] == 29764)

-- Only the pauldrons have two reservers, so they are the doubled one
check("the doubled item is one with two reservers", (function()
	local count = {}
	for _, id in ipairs(ids) do count[id] = (count[id] or 0) + 1 end
	return count[29764] == 2 or count[28830] == nil
end)())

local session = Controller:Start({ 29764, 29764, 28830 })
check("a session starts", session ~= nil and #session.groups == 2 and Controller:State() == "open")
check("no items, no session", Controller:Start({}) == nil)
session = Controller:Start({ 29764, 29764, 28830 })

-- Everybody says MS (random always 4 = pass is choices[3]? we pick by number): 1 -> MS for the testers
local function rng(...)
	local queue = { ... }
	return function(a, b)
		local v = table.remove(queue, 1)
		if v == nil then v = (b == 5) and 2 or 1 end -- a reserver says MS, a tester says MS
		return v
	end
end
check("fill works", Controller:FillTest(rng()) == true)
local group = session.groups[1]
local info = Controller:GroupInfo(group)
check("the item row counts the answers", info.itemID == 29764 and info.copies == 2 and info.counts.reservers == 2 and info.counts.MS == 6)
check("and says so while open", info.status == "SR 2/2 · MS 6 · OS 0 · Pass 0" and info.waiting == 0)
check("only Resolve can be pressed", Controller:Can().resolve and not Controller:Can().reroll and not Controller:Can().accept)

-- Resolve with fixed rolls: the two reservers (2 copies) win without a tie
local ok = session:Resolve(function() return 50 end)
check("resolve ran", ok ~= nil)
-- two copies, two reservers: both win whatever they roll; the trinket has Erik as the only reserver
info = Controller:GroupInfo(session.groups[1])
check("two copies, two reservers: both win", info.status:find("Winner:", 1, true) and info.status:find("Allemano", 1, true) and info.status:find("Erikdbest", 1, true))
check("the single-copy item goes to its reserver", Controller:GroupInfo(session.groups[2]).status:find("Winner: Erikdbest", 1, true) ~= nil)
check("Accept can be pressed", Controller:Can().accept and not Controller:Can().reroll)

-- A tie: one copy, both rolls equal
Controller:Start({ 29764 })
Controller:FillTest(rng())
session = Controller.session
session:Resolve(function() return 50 end)
info = Controller:GroupInfo(session.groups[1])
check("a tie is shown with the names", info.tied == true and info.status:find("Tie:", 1, true) ~= nil)
check("Reroll can be pressed, Accept cannot", Controller:Can().reroll and not Controller:Can().accept)
check("Accept is refused while tied", select(1, Controller:Accept(tostring)) == nil)
local queue = { 10, 90 }
session:Reroll(1, function() return table.remove(queue, 1) end)
info = Controller:GroupInfo(session.groups[1])
check("a reroll decides it", not info.tied and info.status:find("Winner:", 1, true) ~= nil)

-- Rows and texts
local rows = session:Rows(1)
check("the rows start with the winner", rows[1].outcome == "won" and Controller.OutcomeText(rows[1]) == "Won (Soft reserve)")
check("a reroll is shown after the roll", Controller.RollText(rows[1]):find(" > ", 1, true) ~= nil or Controller.RollText(rows[2]):find(" > ", 1, true) ~= nil)
check("no roll is a dash", Controller.RollText({}) == "-")

-- Accept gives chat lines
local lines = Controller:Accept(function(id) return "item" .. id end)
check("accepting gives a line per award", lines and #lines == 1 and lines[1]:find("item29764 ->", 1, true) ~= nil)
check("the session is accepted", Controller:State() == "accepted")

-- An item nobody wants
Controller:Start({ 99999 })
Controller:FillTest(rng(3, 3, 3, 3)) -- all four testers pass
session = Controller.session
session:Resolve()
check("an item nobody wants says so", Controller:GroupInfo(session.groups[1]).status == "Nobody wants it")
lines = Controller:Accept(function(id) return "item" .. id end)
check("and is listed as unclaimed", lines and #lines == 1 and lines[1]:find("nobody wants it", 1, true) ~= nil)

-- Rows before and after Resolve
Controller:Start({ 29764 })
Controller:FillTest(rng())
session = Controller.session
local before = Controller:Rows(session.groups[1])
check("before Resolve the rows are the answers, reservers marked", #before == 6 and before[1].answer == "MS" and before[1].reserved == true and before[3].reserved == false)
session:Resolve(function() return 50 end)
local after = Controller:Rows(session.groups[1])
check("after Resolve the rows have rolls and outcomes", #after == 6 and after[1].roll == 50 and after[1].outcome ~= nil)
check("a reserver row carries the class from the list", before[1].class == "Druid" and before[3].class == nil)
check("no group, no rows", #Controller:Rows(nil) == 0)

-- A reserver who has not answered is listed, first while answers come in and last after Resolve
Controller:Start({ 29764 })
session = Controller.session
session:Answer(1, "Erikdbest", "MS")
local g = session.groups[1]
local open = Controller:Rows(g)
check("a reserver who has not answered is listed first", #open == 2 and open[1].name == "Allemano" and open[1].waiting == true and open[1].reserved == true)
check("then the ones who answered", open[2].name == "Erikdbest" and open[2].waiting == nil)
check("the item row counts them", Controller:GroupInfo(g).status == "SR 1/2 · MS 1 · OS 0 · Pass 0" and Controller:GroupInfo(g).waiting == 1)
session:Answer(1, "Allemano Moo", "PASS")
check("a passer has answered, a surname matches the list's first name", Controller:GroupInfo(g).waiting == 0 and Controller:GroupInfo(g).status:find("SR 2/2", 1, true) ~= nil)
Controller:Start({ 29764 })
session = Controller.session
session:Answer(1, "Erikdbest", "MS")
session:Resolve(function() return 50 end)
local done = Controller:Rows(session.groups[1])
check("after Resolve the silent reserver comes last", #done == 2 and done[1].name == "Erikdbest" and done[2].waiting == true and done[2].outcome == "silent")
check("an item nobody reserved has no SR part", (function()
	Controller:Start({ 12345 })
	return Controller:GroupInfo(Controller.session.groups[1]).status == "MS 0 · OS 0 · Pass 0"
end)())

if failed > 0 then
	print(failed .. " failed")
	os.exit(1)
end
print("ALL OK")
