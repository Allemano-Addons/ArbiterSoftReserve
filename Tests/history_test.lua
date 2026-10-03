-- Offline test of SoftRes/History.lua (what /asr results shows). Run from the ArbiterSoftReserve folder:
--   lua Tests/history_test.lua
time = os.time -- the game's global

local failed = 0
local function check(name, ok)
	if not ok then
		failed = failed + 1
		print("FAIL: " .. name)
	end
end

local ASR = { db = {} }
assert(loadfile("SoftRes/History.lua"))("ArbiterSoftReserve", ASR)
local History = ASR.SoftRes.History

check("nothing is recorded to begin with", #History.Sessions() == 0)

local rows1 = {
	{ name = "Allemano", answer = "MS", roll = 80, outcome = "won", via = "SR", reserved = true },
	{ name = "Erikdbest", answer = "OS", roll = 12, rerolls = { 40, 7 }, outcome = "lost" },
	{ name = "Tester", answer = "PASS", outcome = "passed", reserved = true, silent = true },
}
check("a result is recorded", History.Record("sid-1", 1, 29764, "accepted", rows1, 1000, "Allemano Moo") == true)
check("without a session id, an item or an item ID nothing is recorded",
	not History.Record(nil, 1, 1, "accepted", rows1) and not History.Record("x", nil, 1, "accepted", rows1) and not History.Record("x", 1, nil, "accepted", rows1))
check("a second item joins the same session", History.Record("sid-1", 2, 28830, "resolved", { { name = "Erikdbest", answer = "MS", roll = 55, outcome = "tied" } }, 1000) == true
	and #History.Sessions() == 1)
rows1[1].roll = 1
check("what was recorded is a copy", History.Rows(History.Sessions()[1].items[1])[1].roll == 80)
check("the silent flag and the rerolls are kept", History.Rows(History.Sessions()[1].items[1])[3].silent == true and History.Rows(History.Sessions()[1].items[1])[2].rerolls[2] == 7)

-- A later result of the same item replaces the earlier one
History.Record("sid-1", 2, 28830, "accepted", { { name = "Erikdbest", answer = "MS", roll = 55, outcome = "won", via = "MS" } }, 1000)
check("the latest result of an item wins", History.Sessions()[1].items[2].state == "accepted" and History.Rows(History.Sessions()[1].items[2])[1].outcome == "won")

-- By item
local session = History.Sessions()[1]
local items = History.ByItem(session)
check("by item: in item order", #items == 2 and items[1].number == 1 and items[2].number == 2)
check("with the winners", #items[1].winners == 1 and items[1].winners[1] == "Allemano" and items[2].winners[1] == "Erikdbest")
check("how many rolled and how many stayed silent", items[1].rolled == 2 and items[1].silent == 1)
check("and no tie once decided", items[1].tied == false and items[2].tied == false)

-- By player
local players = History.ByPlayer(session)
check("by player: the ones with most wins first", #players == 3 and players[1].wins == 1 and players[2].wins == 1 and players[3].wins == 0)
check("then by name", players[1].name == "Allemano" and players[2].name == "Erikdbest" and players[3].name == "Tester")
check("a player has a line for every item", #players[2].entries == 2 and players[2].entries[1].number == 1 and players[2].entries[2].number == 2)
check("with the answer, roll and rerolls", players[2].entries[1].roll == 12 and players[2].entries[1].rerolls[1] == 40 and players[2].entries[1].outcome == "lost")
check("how many they rolled for", players[2].rolled == 2 and players[3].rolled == 0)
check("a silent reserver is there too", players[3].entries[1].silent == true)
check("the same name in another case is the same player", (function()
	local s = { items = { [1] = { itemID = 1, state = "accepted", rows = { { name = "Bob", answer = "MS", roll = 5, outcome = "lost" } } },
		[2] = { itemID = 2, state = "accepted", rows = { { name = "bob", answer = "MS", roll = 9, outcome = "won", via = "MS" } } } } }
	local p = History.ByPlayer(s)
	return #p == 1 and #p[1].entries == 2 and p[1].wins == 1
end)())
check("a tie is shown as not decided", History.ByItem({ items = { [1] = { itemID = 1, state = "resolved", rows = { { name = "A", answer = "MS", roll = 5, outcome = "tied" } } } } })[1].tied == true)

-- The rows are kept as text and come back the same; an older save with tables is read as it is
local sample = { { name = "Bob Moo", answer = "OS", roll = 37, rerolls = { 90, 12 }, outcome = "won", via = "OS", reserved = true },
	{ name = "Ann", answer = "PASS", outcome = "passed", reserved = true, silent = true }, { name = "Cy", answer = "MS", roll = 5, outcome = "lost" } }
History.Record("sid-pack", 1, 77, "accepted", sample, 1)
local packedItem = History.Sessions()[1].items[1]
check("an item keeps its rows as one text", type(packedItem.packed) == "string" and packedItem.rows == nil)
local back = History.Rows(packedItem)
check("and gives them back as they were", #back == 3 and back[1].name == "Bob Moo" and back[1].roll == 37 and back[1].rerolls[2] == 12 and back[1].via == "OS" and back[1].reserved == true and back[1].silent == nil)
check("with the flags, the missing roll and the empty fields right", back[2].silent == true and back[2].reserved == true and back[2].roll == nil and back[2].rerolls == nil and back[2].via == nil and back[3].reserved == nil and back[3].outcome == "lost")
local deRows = { { name = "Bob", answer = "PASS", outcome = "passed", disenchant = true }, { name = "Ann", answer = "MS", roll = 5, outcome = "lost" } }
History.Record("sid-de", 1, 55, "accepted", deRows, 1)
local deItem = History.ByItem(History.Sessions()[1])[1]
check("the disenchant flag survives the packed text", History.Rows(History.Sessions()[1].items[1])[1].disenchant == true and History.Rows(History.Sessions()[1].items[1])[2].disenchant == nil)
check("by item says who the item was handed to", #deItem.disenchanted == 1 and deItem.disenchanted[1] == "Bob" and #deItem.winners == 0)
check("by player carries the flag", History.ByPlayer(History.Sessions()[1])[1].entries[1].disenchant == true or History.ByPlayer(History.Sessions()[1])[2].entries[1].disenchant == true)
History.Delete("sid-de")
check("an older save with a table of rows is read as it is", History.Rows({ itemID = 1, rows = { { name = "Old", answer = "MS" } } })[1].name == "Old")
check("a nothing is nothing", #History.Rows(nil) == 0 and #History.Rows({ itemID = 1 }) == 0)
History.Delete("sid-pack")

-- Newest first, at most MAX_SESSIONS
for i = 2, History.MAX_SESSIONS + 3 do
	History.Record("sid-" .. i, 1, 1, "accepted", { { name = "P", answer = "MS", roll = i, outcome = "won", via = "MS" } }, 1000 + i)
end
local list = History.Sessions()
check("the oldest sessions go", #list == History.MAX_SESSIONS and list[1].sid == "sid-" .. (History.MAX_SESSIONS + 3) and list[#list].sid ~= "sid-1")

-- A result taken back (Reopen) is forgotten, and a session without items disappears
History.Record("sid-solo", 1, 5, "accepted", { { name = "A", answer = "MS", roll = 1, outcome = "won", via = "MS" } }, 5000)
check("the session is there", History.Sessions()[1].sid == "sid-solo")
History.Record("sid-solo", 1, 5, "resolved", {}, 5000)
check("an item with no rows is forgotten and the empty session goes", History.Sessions()[1].sid ~= "sid-solo")
check("an empty result for an unknown session records nothing", History.Record("sid-new", 1, 5, "resolved", {}, 5000) == false and History.Sessions()[1].sid ~= "sid-new")

local countBefore = #History.Sessions()
check("a session can be deleted", History.Delete(History.Sessions()[1].sid) == true and #History.Sessions() == countBefore - 1)
check("an unknown session cannot", History.Delete("nope") == false)
History.Clear()
check("Clear forgets everything", #History.Sessions() == 0)

-- The long lists are cut
local many = {}
for i = 1, 100 do many[i] = { name = "Player" .. i, answer = "MS", roll = i, outcome = "lost" } end
History.Record("sid-big", 1, 1, "accepted", many, 1)
check("a very long list is cut", #History.Rows(History.Sessions()[1].items[1]) == History.MAX_ROWS)

-- The class of a player is kept with their row, for the colour of the name
do
	History.Clear()
	ASR.SoftRes.ClassOf = function(name) if name == "Bob" then return "DRUID" end end
	History.Record("sid-cls", 1, 66, "accepted", { { name = "Bob", answer = "MS", roll = 9, outcome = "won", via = "MS" }, { name = "Ann", answer = "MS", roll = 3, outcome = "lost" } }, 1)
	local rows = History.Rows(History.Sessions()[1].items[1])
	check("a row keeps the class the name had when it was recorded", rows[1].class == "DRUID" and rows[2].class == nil)
	check("by item carries it", History.ByItem(History.Sessions()[1])[1].rows[1].class == "DRUID")
	check("by player has the player's class", History.ByPlayer(History.Sessions()[1])[1].class == "DRUID" and History.ByPlayer(History.Sessions()[1])[1].entries[1].class == "DRUID")
	History.Record("sid-cls", 1, 66, "accepted", { { name = "Cy", answer = "MS", roll = 1, outcome = "lost", class = "MAGE" } }, 1)
	check("a class the row brings is not overwritten", History.Rows(History.Sessions()[1].items[1])[1].class == "MAGE")
	ASR.SoftRes.ClassOf = nil
	History.Clear()
end

-- From Arbiter Loot Council
ALC = {
	Sessions = { GetSession = function() return { sid = "sid-alc", lm = "Allemano Moo", items = { [1] = { itemID = 29764 } } } end },
	Results = { Get = function(_, item) return { { name = "Allemano", answer = "MS", roll = 50, outcome = "won", via = "MS" } }, "accepted" end },
	Events = { Register = function(owner, event, fn) ALC.registered = { owner = owner, event = event, fn = fn } end },
}
History.Clear()
check("a result that arrives is recorded", History.RecordFromALC(1) == true and History.Sessions()[1].sid == "sid-alc" and History.Sessions()[1].lm == "Allemano Moo")
check("an item that is not in the session is not", History.RecordFromALC(9) == false and History.RecordFromALC(nil) == false)
History.Clear()
check("Init listens for ALC's results", History.Init() == true and ALC.registered.event == "ALC_RESULTS_CHANGED")
ALC.registered.fn(nil, 1)
check("and records them as they come", #History.Sessions() == 1)
ALC.registered.fn(nil, nil)
check("the clearing of ALC's results is not a result", #History.Sessions() == 1)
ALC = nil
check("without ALC there is nothing to listen to", History.Init() == false and History.RecordFromALC(1) == false)

if failed > 0 then
	print(failed .. " failed")
	os.exit(1)
end
print("ALL OK")
