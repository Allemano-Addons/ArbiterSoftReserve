-- Offline test of SoftRes/Bridge.lua (the link to Arbiter Loot Council) against a stand-in for ALC.
-- Run from the ArbiterSoftReserve folder:  lua Tests/bridge_test.lua
time = os.time -- the game's global

local failed = 0
local function check(name, ok)
	if not ok then
		failed = failed + 1
		print("FAIL: " .. name)
	end
end

local ASR = { db = {} }
local function load(file) assert(loadfile("SoftRes/" .. file .. ".lua"))("ArbiterSoftReserve", ASR) end
for _, file in ipairs({ "Import", "Rules", "Session", "Controller", "Bridge" }) do load(file) end
local SoftRes = ASR.SoftRes
local Controller, Bridge = SoftRes.Controller, SoftRes.Bridge

local HEADER = "Item Name,Item ID,From,Raider Name,Raider Class,Raider Spec,Raider Note,Extra Reserves,Date"
local function importMain()
	SoftRes:Import(table.concat({
		HEADER,
		"Pauldrons,29764,Maulgar,Allemano,Druid,Balance,,0,x",
		"Pauldrons,29764,Maulgar,Erikdbest,Warrior,Fury,,0,x",
		"Trinket,28830,Gruul,Erikdbest,Warrior,Fury,,0,x",
	}, "\n"))
end
importMain()

-- Without ALC, or with an ALC that has no API
check("without ALC the bridge says so", Bridge.Available() == false and select(2, Bridge.Available()):find("too old", 1, true) ~= nil)
check("and Start fails with the same message", select(1, Bridge.Start({ 29764 })) == false)

-- A stand-in for ALC
local api = 1
local handlers, started = {}, {}
local lists, rolled, published, asked = {}, {}, {}, {}
ALC = {
	HasAPI = function(n) return api >= n end,
	Events = { Register = function(_, event, fn) handlers[event] = fn end },
	Sessions = { StartItems = function(_, list, options) started[#started + 1] = { list = list, options = options } return true, "sid-1" end },
	AwardDialog = { AskMany = function(_, list) asked[#asked + 1] = list return true end },
	Results = { Publish = function(_, item, state, rows) published[#published + 1] = { item = item, state = state, rows = rows } return true end },
	Candidates = {
		GetList = function(_, slot) return lists[slot] or {} end,
		SetRoll = function(_, name, roll, slot) rolled[#rolled + 1] = { name = name, roll = roll, slot = slot } return true end,
	},
}
check("ALC API 1 is too old", Bridge.Available() == false and select(2, Bridge.Available()):find("API 5", 1, true) ~= nil)
api = 4
check("and so is API 4 (no Start SR button yet)", Bridge.Available() == false)
api = 5
check("ALC API 5 is fine", Bridge.Available() == true)

-- The options
local options = Bridge.Options({ 29764, 29764, 28830, 99999 })
check("the mode is SR and ALC does not roll", options.mode == "SR" and options.rolls == false)
check("it has a name and ASR's purple for ALC's windows", options.modeName == "Soft Reserve" and options.modeColor == "9B7BFF")
check("the answers are MS, OS and Pass last", #options.responses == 3 and options.responses[1].id == "MS" and options.responses[3].id == "PASS")
check("each item says who reserved it, for the SR tag", options.extra[1].mark == "SR" and options.extra[1].markFor[1] == "Allemano" and options.extra[1].markFor[2] == "Erikdbest" and options.extra[3].markFor[1] == "Erikdbest")
check("and how many copies there are", options.extra[1].copies == 2 and options.extra[2].copies == 2 and options.extra[3].copies == 1)
check("an item nobody reserved has no tag", options.extra[4].markFor == nil and options.extra[4].mark == nil and options.extra[4].copies == 1)

local lines = { HEADER }
for i = 1, 60 do lines[#lines + 1] = ",1,,Player" .. i .. ",,,,0," end
SoftRes:Import(table.concat(lines, "\n"))
check("a long list is cut at what ALC accepts", #Bridge.Options({ 1 }).extra[1].markFor == 40)
SoftRes:Import(HEADER .. "\n,2,,X,,,,0,\n,2,,Valid Name,,,,0,")
check("a one-letter name that ALC would refuse is left out", #Bridge.Options({ 2 }).extra[1].markFor == 1)
importMain()

-- Starting
check("no items, no session", Bridge.Start({}) == false and #started == 0)
local ok, sid = Bridge.Start({ 29764, 29764, 28830 })
check("a session is started in ALC", ok == true and sid == "sid-1" and #started == 1 and started[1].list[3] == 28830)
check("with the soft reserve options", started[1].options.mode == "SR" and started[1].options.extra[2].copies == 2)

-- The events
check("the bridge listens to ALC", Bridge.Init() == true and handlers.ALC_SESSION_STARTED and handlers.ALC_CANDIDATES_CHANGED and handlers.ALC_SESSION_ENDED)
handlers.ALC_SESSION_STARTED(nil, { mode = nil, isLM = true, items = { { itemID = 1 } }, sid = "plain" })
check("a normal session is none of ASR's business", Controller.session == nil)
handlers.ALC_SESSION_STARTED(nil, { mode = "SR", isLM = false, items = { { itemID = 1 } }, sid = "other" })
check("and neither is another loot master's", Controller.session == nil)
ASR.SessionWindow = { shown = 0, refreshed = 0 }
function ASR.SessionWindow:Show() self.shown = self.shown + 1 end
function ASR.SessionWindow:Refresh() self.refreshed = self.refreshed + 1 end
handlers.ALC_SESSION_STARTED(nil, { mode = "SR", isLM = true, items = { { itemID = 29764 }, { itemID = 29764 }, { itemID = 28830 } }, sid = "sid-1" })
check("our soft reserve session makes the ASR session", Controller.session ~= nil and #Controller.session.groups == 2 and Controller.live == "sid-1")
check("and opens the window", ASR.SessionWindow.shown == 1)

-- Answers: slots 1 and 2 are copies of the pauldrons, slot 3 the trinket
lists[1] = { { name = "Allemano Moo", response = "MS" }, { name = "Tester One", response = "OS" } }
lists[2] = { { name = "Allemano Moo", response = "OS" }, { name = "Erikdbest Moo", response = "MS" }, { name = "Tester Two", response = "PASS" } }
lists[3] = { { name = "Erikdbest Moo", response = "MS" } }
local read = Bridge.Sync()
check("the answers are read", read == 5)
local group = Controller.session.groups[1]
check("the lowest slot with an answer counts", group.entries["allemano moo"].answer == "MS")
check("a player who answered only the second copy counts", group.entries["erikdbest moo"].answer == "MS")
check("a pass is an answer", group.entries["tester two"].answer == "PASS")
check("the trinket is answered too", Controller.session.groups[2].entries["erikdbest moo"].answer == "MS")
check("reservers are found by first name", Controller.session.isReserver("Allemano Moo", 29764) == true)

-- A change of mind is picked up while the session is open
lists[1][1].response = "OS"
Bridge.Sync()
check("a changed answer replaces the old", group.entries["allemano moo"].answer == "OS")

-- The candidates event syncs and redraws the window
lists[1][1].response = "MS"
local refreshed = ASR.SessionWindow.refreshed
handlers.ALC_CANDIDATES_CHANGED()
check("candidates changing reads the answers and redraws", group.entries["allemano moo"].answer == "MS" and ASR.SessionWindow.refreshed == refreshed + 1)

-- Resolve, then the rolls go to ALC
Controller.session:Resolve(function() return 40 end)
local pushed = Bridge.PushRolls()
check("every roll is handed to ALC, once per slot of the item", pushed > 0 and #rolled == pushed)
local forAllemano = {}
for _, r in ipairs(rolled) do if r.name == "Allemano Moo" then forAllemano[#forAllemano + 1] = r.slot end end
table.sort(forAllemano)
check("a copy's roll goes to both slots", forAllemano[1] == 1 and forAllemano[2] == 2 and rolled[1].roll == 40)
local passRolled = false
for _, r in ipairs(rolled) do if r.name == "Tester Two" then passRolled = true end end
check("a pass has no roll", not passRolled)

-- The result goes to everybody: one message per group of copies, winners first
published = {}
check("results are published for each item", Bridge.PublishResults("resolved") == 2 and #published == 2)
check("to the first slot of the copies", published[1].item == 1 and published[2].item == 3 and published[1].state == "resolved")
local sent = published[1].rows
check("with a row per player", #sent >= 3 and sent[1].name and sent[1].answer and sent[1].outcome)
check("winners come first", sent[1].outcome == "won")
check("nothing ASR keeps for itself is sent", sent[1].class == nil and sent[1].entry == nil)
local silentRow
for _, r in ipairs(sent) do if r.silent then silentRow = r end end
for _, r in ipairs(sent) do if r.waiting then silentRow = nil break end end
check("a reserver who never answered is sent as a Pass with the silent flag",
	silentRow == nil or (silentRow.answer == "PASS" and silentRow.outcome == "passed" and silentRow.reserved == true and silentRow.roll == nil))
local waiting = { name = "Silent Reserver", waiting = true, reserved = true, outcome = "silent" }
local s1 = Controller.session.groups[1]
local realRows = Controller.Rows
Controller.Rows = function(self, group) local rows = realRows(self, group) rows[#rows + 1] = waiting return rows end
published = {}
Bridge.PublishResults("resolved")
Controller.Rows = realRows
local last = published[1].rows[#published[1].rows]
check("a reserver who has not answered goes out as a silent Pass", last.name == "Silent Reserver" and last.answer == "PASS" and last.outcome == "passed"
	and last.silent == true and last.reserved == true and last.roll == nil and last.waiting == nil)
published = {}
Bridge.PublishResults("resolved")
published = {}
Controller.session:Reopen()
Bridge.PublishResults("resolved")
check("after Reopen the items are sent with no rows", #published == 2 and #published[1].rows == 0)
Controller.session:Resolve(function() return 40 end)

-- Accepting: the winners go to ALC's "Award all" question
check("nothing to award before Accept", select(1, Bridge.RequestAwards()) == false and #asked == 0)
local lines = Controller:Accept(tostring)
check("accepting gives the chat lines", lines ~= nil and #lines >= 2)
local awardList = Bridge.AwardList()
check("the award list has a winner per copy and item", #awardList == 3 and awardList[1].item == 1 and awardList[2].item == 2 and awardList[3].item == 3)
check("with the player's name", awardList[1].name and awardList[1].name:find("Moo", 1, true) ~= nil)
check("and why they won", awardList[1].note:find("SR", 1, true) ~= nil and awardList[1].note:find("roll 40", 1, true) ~= nil)
check("the question is shown with that list", Bridge.RequestAwards() == true and #asked == 1 and asked[1][1].item == 1 and #asked[1] == 3)
local dialog = ALC.AwardDialog
ALC.AwardDialog = nil
check("an ALC without the question says so", select(2, Bridge.RequestAwards()):find("too old", 1, true) ~= nil)
ALC.AwardDialog = dialog

-- Items nobody wanted go to the disenchanter in the same question
local realUnclaimed = Controller.unclaimed
Controller.unclaimed = { 7, 9 }
check("without ALC's disenchant check nothing is offered", #Bridge.DisenchantList() == 0)
local canDE, deWhy = true, nil
ALC.Awards = { CanDisenchant = function() return canDE, deWhy end }
local deList = Bridge.DisenchantList()
check("the unclaimed items are offered to the disenchanter", #deList == 2 and deList[1].item == 7 and deList[1].disenchant == true and deList[2].item == 9 and deList[1].note == "Nobody wanted it")
local withDE = Bridge.AwardList()
check("after the winners in the award list", #withDE == 5 and withDE[3].name ~= nil and withDE[4].disenchant == true and withDE[5].item == 9)
ASR.db = ASR.db or {}
ASR.db.disenchant = false
check("/asr disenchant off leaves them alone", #Bridge.DisenchantList() == 0 and #Bridge.AwardList() == 3)
ASR.db.disenchant = nil
canDE, deWhy = false, "No disenchanter is set."
local noDE, why = Bridge.DisenchantList()
check("without a disenchanter nothing is offered, and it says why", #noDE == 0 and why == "No disenchanter is set." and #Bridge.AwardList() == 3)
local told = {}
local realPrint = ASR.Print
ASR.Print = function(_, text) told[#told + 1] = text end
Bridge.RequestAwards()
check("the loot master is told why they are left alone", #told == 1 and told[1]:find("No disenchanter is set.", 1, true) ~= nil and told[1]:find("2 of the items", 1, true) ~= nil)
ASR.Print = realPrint
Controller.unclaimed = {}
check("nothing unclaimed, nothing offered", #Bridge.DisenchantList() == 0)
Controller.unclaimed = realUnclaimed
ALC.Awards = nil

-- A reroll: the last number is the one shown (one copy, two reservers, equal rolls)
handlers.ALC_SESSION_ENDED(nil, "sid-1")
handlers.ALC_SESSION_STARTED(nil, { mode = "SR", isLM = true, items = { { itemID = 29764 } }, sid = "sid-2" })
lists = { [1] = { { name = "Allemano Moo", response = "MS" }, { name = "Erikdbest Moo", response = "MS" } } }
Bridge.Sync()
local tieSession = Controller.session
tieSession:Resolve(function() return 50 end)
check("equal rolls need a reroll", #tieSession.groups[1].result.ties == 1)
local queue = { 12, 80 }
tieSession:Reroll(1, function() return table.remove(queue, 1) end)
rolled = {}
Bridge.PushRolls()
local byName = {}
for _, r in ipairs(rolled) do byName[r.name] = r.roll end
check("after a reroll ALC gets the new numbers", byName["Allemano Moo"] == 12 and byName["Erikdbest Moo"] == 80)
check("and the reroll decided it", #tieSession.groups[1].result.ties == 0)
group = tieSession.groups[1]
handlers.ALC_SESSION_ENDED(nil, "sid-2")
handlers.ALC_SESSION_STARTED(nil, { mode = "SR", isLM = true, items = { { itemID = 29764 }, { itemID = 29764 }, { itemID = 28830 } }, sid = "sid-1" })

-- Handed to the disenchanter: ASR learns it from ALC's award and publishes the results again
ALC.Constants = { DISENCHANT_ID = "DISENCHANT" }
published = {}
handlers.ALC_COMM_AWARD(nil, "Lm Moo", "sid-1", { item = 2, winner = "Allemano Moo", response = "BIS" })
check("an ordinary award changes nothing", Controller.session.groups[1].disenchanted == nil and #published == 0)
handlers.ALC_COMM_AWARD(nil, "Lm Moo", "other-sid", { item = 2, winner = "Allemano Moo", response = "DISENCHANT" })
check("an award in another session changes nothing", Controller.session.groups[1].disenchanted == nil and #published == 0)
handlers.ALC_COMM_AWARD(nil, "Lm Moo", "sid-1", { item = 2, winner = "Allemano Moo", response = "DISENCHANT" })
check("an item handed to the disenchanter is remembered", Controller.session.groups[1].disenchanted and Controller.session.groups[1].disenchanted[1] == "Allemano Moo")
check("and the results go out again for everybody", #published >= 1 and published[1].state == "accepted")
ALC.Constants = nil

-- After the answers are closed nothing is read
lists = { [1] = { { name = "Allemano Moo", response = "MS" } } }
Bridge.Sync()
Controller.session:Resolve(function() return 40 end)
lists[1][1].response = "PASS"
Bridge.Sync()
check("answers after Resolve are not read", Controller.session.groups[1].entries["allemano moo"].answer == "MS")

-- The session ends
handlers.ALC_SESSION_ENDED(nil, "somebody-else")
check("another session ending changes nothing", Controller.live == "sid-1")
handlers.ALC_SESSION_ENDED(nil, "sid-1")
check("ours ending clears the live mark", Controller.live == nil)
check("the window redraws", ASR.SessionWindow.refreshed > refreshed)

-- ALC's Loot window: "Start SR"
local registered
ALC.RegisterStartMode = function(def) registered = def return true end
check("the start button is registered with ALC", Bridge.RegisterStartMode() == true and registered.id == "SR" and registered.label == "SR"
	and registered.name == "Soft Reserve" and registered.color == "9B7BFF" and type(registered.start) == "function")
local before = #started
local okLinks = registered.start({ "item:29764:0:0:0", "|cff1eff00|Hitem:28830::::::::70:|h[Gruul]|h|r", 4711 })
check("the items of the Loot window start a soft reserve session", okLinks == true and #started == before + 1
	and started[#started].list[1] == 29764 and started[#started].list[2] == 28830 and started[#started].list[3] == 4711
	and started[#started].options.mode == "SR")
local entries = {}
ALC.RegisterLauncherEntry = function(def) entries[#entries + 1] = def return true end
check("ASR adds its rows to ALC's window menu", Bridge.RegisterLauncherEntries() == true and #entries == 3)
check("under the Soft Reserve heading in ASR's colour", entries[1].section == "Soft Reserve" and entries[1].color == "9B7BFF" and entries[1].id == "asr-results")
local keptSession = Controller.session
Controller.session = nil
check("Results is always available, the session only when there is one", entries[1].available == nil and entries[2].available() == false
	and select(2, entries[2].available()):find("/asr start", 1, true) ~= nil)
Controller.session = keptSession
check("and it is there while a session runs", entries[2].available() == true)
check("Results and Import open ASR's windows", (function()
	local shown = {}
	ASR.ResultsWindow = { Toggle = function() shown.results = true end }
	ASR.ImportWindow = { Show = function() shown.import = true end }
	entries[1].open()
	entries[3].open()
	return shown.results and shown.import
end)())
api = 4
check("an ALC without the API adds no button", Bridge.RegisterStartMode() == false and Bridge.RegisterLauncherEntries() == false)
api = 5

if failed > 0 then
	print(failed .. " failed")
	os.exit(1)
end
print("ALL OK")
