-- Offline test of SoftRes/Session.lua: a whole soft reserve session, from the answers to the awards.
-- Run from the ArbiterSoftReserve folder:  lua Tests/session_test.lua
time = os.time -- the game's global

local failed = 0
local function check(name, ok)
	if not ok then
		failed = failed + 1
		print("FAIL: " .. name)
	end
end

local ASR = { db = {} }
assert(loadfile("SoftRes/Import.lua"))("ArbiterSoftReserve", ASR)
assert(loadfile("SoftRes/Rules.lua"))("ArbiterSoftReserve", ASR)
assert(loadfile("SoftRes/Session.lua"))("ArbiterSoftReserve", ASR)
local SoftRes = ASR.SoftRes
local Session = SoftRes.Session

-- The list: Allemano and Erik reserved the tier token (29764), Gavz the hammer (28800).
local csv = table.concat({
	"Item Name,Item ID,From,Raider Name,Raider Class,Raider Spec,Raider Note,Extra Reserves,Date",
	"Pauldrons,29764,Maulgar,Allemano,Druid,Balance,,0,x",
	"Pauldrons,29764,Maulgar,Erikdbest,Warrior,Fury,,0,x",
	"Pauldrons,29764,Maulgar,Gavztahx,Paladin,Protection,,0,x",
	"Hammer,28800,Maulgar,Gavztahx,Paladin,Protection,,0,x",
}, "\n")
SoftRes:Import(csv)

-- A queue of rolls for the test
local queue = {}
local function rolls(...) queue = { ... } end
local function fake() return table.remove(queue, 1) end

-- Slots: 1 = the hammer, 2 and 3 = two tier tokens, 4 = a trinket nobody reserved
local items = { { itemID = 28800 }, { itemID = 29764 }, { itemID = 29764 }, { itemID = 28830 } }
local s = Session.New(items)

check("copies of one item are one group", #s.groups == 3 and s.byItem[29764].copies == 2 and s.slotGroup[2] == s.slotGroup[3])
check("a new session is open", s.state == "open")

-- Answers
check("a wrong answer is refused", s:Answer(1, "Gavztahx", "maybe") == false)
check("an item that is not there is refused", s:Answer(9, "Gavztahx", "MS") == false)
check("a missing name is refused", s:Answer(1, "", "MS") == false)
check("MS is accepted", s:Answer(1, "Gavztahx Moo", "ms") == true)
s:Answer(2, "Allemano Moo", "MS")      -- answers on one copy count for the group
s:Answer(3, "Erikdbest Moo", "OS")     -- a reserver who answers OS still counts as one
s:Answer(2, "Gavztahx Moo", "MS")
s:Answer(2, "Kaelis Moo", "MS")        -- no reserve
s:Answer(2, "Veyra Moo", "MS")
s:Answer(4, "Kaelis Moo", "MS")
s:Answer(4, "Veyra Moo", "OS")
s:Answer(1, "Kaelis Moo", "PASS")
s:Answer(1, "Allemano Moo", "MS")
s:Answer(1, "Allemano Moo", "PASS")    -- changed his mind
local counts = s:Counts(2)
check("the answers are counted", counts.MS == 4 and counts.OS == 1 and counts.PASS == 0 and counts.copies == 2)
check("and the reservers among them", counts.reservers == 3)
check("a changed answer replaces the old", s:Counts(1).PASS == 2 and s:Counts(1).MS == 1)
check("nothing is decided before Resolve", s:IsDecided() == false and #s:Rows(1) == 0)
check("cannot reroll before Resolve", s:Reroll(1) == false)
check("cannot accept before Resolve", s:Accept() == nil)

-- Resolve. Rolls are made in the order the players answered, per item group:
-- hammer: Gavz, Kaelis (pass: no roll), Allemano (pass: no roll)  -> 1 roll
-- tokens: Allemano, Erik, Gavz, Kaelis, Veyra                        -> 5 rolls
-- trinket: Kaelis, Veyra                                             -> 2 rolls
rolls(50,                      70, 70, 70, 99, 20,                     40, 90)
local waiting = s:Resolve(fake)
check("Resolve says how many items wait for a reroll", waiting == 1)
check("the session is resolved", s.state == "resolved" and #queue == 0)

local hammer = s:Rows(1)
check("the hammer goes to its only reserver who answered MS", hammer[1].name == "Gavztahx Moo" and hammer[1].outcome == "won" and hammer[1].via == "SR")
check("those who passed show as passed", hammer[#hammer].outcome == "passed" and hammer[#hammer].roll == nil)

-- tokens: reservers Allemano 70, Erik 70, Gavz 70 -> three-way tie for two copies
local tokens = s:Rows(2)
check("a tie is shown as tied", tokens[1].outcome == "tied" and tokens[2].outcome == "tied" and tokens[3].outcome == "tied")
check("the one with a higher roll but no reserve lost", (function()
	for _, r in ipairs(tokens) do if r.name == "Kaelis Moo" then return r.outcome == "lost" and r.roll == 99 end end
end)())
check("a tie blocks Accept", s:IsDecided() == false and s:Accept() == nil)

local trinket = s:Rows(4)
check("the trinket: MS before OS whatever the rolls", trinket[1].name == "Kaelis Moo" and trinket[1].outcome == "won" and trinket[1].via == "MS" and trinket[2].outcome == "lost")

-- Reroll: three tied for two copies, so one of them is out
check("cannot reroll an item that is not tied", s:Reroll(1) == false)
rolls(80, 80, 80)
local ok, again = s:Reroll(3, fake)
check("a reroll rolls for the three who tied", ok == true and again == true and #queue == 0)
check("they rolled the same again and are still tied", s:IsDecided() == false)
rolls(10, 60, 60)
ok, again = s:Reroll(2, fake)
check("another reroll decides it: two copies for the two highest", ok == true and again == false and s:IsDecided() == true)

local after = s:Rows(2)
local winners = {}
for _, r in ipairs(after) do if r.outcome == "won" then winners[#winners + 1] = r.name end end
table.sort(winners)
check("two copies, two winners, both reservers", #winners == 2 and winners[1] == "Erikdbest Moo" and winners[2] == "Gavztahx Moo")
for _, r in ipairs(after) do
	if r.name == "Kaelis Moo" or r.name == "Veyra Moo" then check(r.name .. " does not win a reserved token", r.outcome == "lost") end
end

-- Accept
local awards, unclaimed = s:Accept()
check("Accept hands over one award for every item with a winner", awards ~= nil and #awards == 4 and #unclaimed == 0)
check("the awards are in slot order", awards[1].slot == 1 and awards[2].slot == 2 and awards[3].slot == 3 and awards[4].slot == 4)
check("the hammer for Gavz, the trinket for Kaelis", awards[1].name == "Gavztahx Moo" and awards[1].itemID == 28800 and awards[4].name == "Kaelis Moo")
check("the two tokens go to two different players", awards[2].name ~= awards[3].name and awards[2].itemID == 29764)
check("the session is accepted and closed", s.state == "accepted" and s:Answer(1, "Veyra Moo", "MS") == false)
check("an accepted result cannot be resolved again", s:Resolve() == nil and s:Reopen() == false)

-- A session with nobody who wants an item, and one that is reopened
local t = Session.New({ { itemID = 28830 }, { itemID = 11111 } })
t:Answer(1, "Kaelis Moo", "PASS")
rolls()
check("an item everybody passed (or nobody answered) is not waiting", t:Resolve(fake) == 0)
local a2, u2 = t:Accept()
check("such items are returned as unclaimed", #a2 == 0 and #u2 == 2)

local r = Session.New({ { itemID = 28830 } })
r:Answer(1, "Kaelis Moo", "MS")
rolls(55)
r:Resolve(fake)
check("a roll is made once", r.groups[1].entries["kaelis moo"].roll == 55)
check("reopening forgets the rolls", r:Reopen() == true and r.state == "open" and r.groups[1].entries["kaelis moo"].roll == nil)
check("and the answers can change again", r:Answer(1, "Kaelis Moo", "OS") == true)
rolls(12)
r:Resolve(fake)
local a3 = r:Accept()
check("the new answer is what counts", a3[1].name == "Kaelis Moo" and a3[1].via == "OS" and a3[1].roll == 12)

-- A reserve is looked up with the character's first name, and the check can be replaced
local custom = Session.New({ { itemID = 5 } }, function(name) return name == "Special" end)
custom:Answer(1, "Special", "MS")
custom:Answer(1, "Other", "MS")
rolls(10, 99)
custom:Resolve(fake)
check("a different way to tell who reserved works", custom:Accept()[1].name == "Special")

-- A snapshot brings the session back after a /reload: the same answers, rolls, ties and winners
do
	local rng = { 50, 50, 80, 10, 40, 77 }
	local function nextRoll() return table.remove(rng, 1) or 33 end
	local s = Session.New({ { itemID = 100 }, { itemID = 100 }, { itemID = 200 } }, function(name, itemID) return name == "Ann" and itemID == 100 end)
	s:Answer(1, "Ann", "MS"); s:Answer(1, "Bob Moo", "MS"); s:Answer(1, "Cy", "OS"); s:Answer(3, "Bob Moo", "MS"); s:Answer(3, "Dee", "PASS")
	s:Resolve(nextRoll)
	local snap = s:Snapshot()
	check("a snapshot is plain data", type(snap) == "table" and snap.state == "resolved" and #snap.items == 3 and #snap.groups == 2 and snap.groups[1].resolved == true)
	local back = Session.Restore(snap, function(name, itemID) return name == "Ann" and itemID == 100 end)
	check("the restored session is in the same state", back ~= nil and back.state == "resolved" and #back.groups == 2)
	local function summary(sess)
		local out = {}
		for _, group in ipairs(sess.groups) do
			for _, key in ipairs(group.order) do
				local e = group.entries[key]
				out[#out + 1] = table.concat({ group.itemID, e.name, e.answer, tostring(e.roll), e.rerolls and table.concat(e.rerolls, "/") or "-" }, ":")
			end
			local names = {}
			for _, w in ipairs(group.result.winners) do names[#names + 1] = w.name .. "=" .. tostring(w.roll) end
			out[#out + 1] = "W " .. table.concat(names, ",")
			out[#out + 1] = "T " .. #group.result.ties
		end
		return table.concat(out, "|")
	end
	check("with the same answers, rolls, winners and ties", summary(back) == summary(s))
	check("and the same rows for the windows", #back:Rows(1) == #s:Rows(1) and back:Rows(1)[1].name == s:Rows(1)[1].name and back:Rows(1)[1].roll == s:Rows(1)[1].roll)
	-- a tie and its reroll survive too
	local t = Session.New({ { itemID = 300 } }, function() return false end)
	t:Answer(1, "Ann", "MS"); t:Answer(1, "Bob", "MS")
	t:Resolve(function() return 50 end)
	check("two equal rolls tie", #t.groups[1].result.ties == 1)
	local tBack = Session.Restore(t:Snapshot(), function() return false end)
	check("the tie is still a tie after the reload", #tBack.groups[1].result.ties == 1 and not tBack:IsDecided())
	local q = { 10, 90 }
	t:Reroll(1, function() return table.remove(q, 1) end)
	local rBack = Session.Restore(t:Snapshot(), function() return false end)
	check("the reroll survives and decided it", rBack:IsDecided() and rBack.groups[1].entries["bob"].rerolls[1] == 90 and rBack.groups[1].result.winners[1].name == "Bob")
	-- an open session keeps its answers and can go on
	local o = Session.New({ { itemID = 400 } }, function() return false end)
	o:Answer(1, "Ann", "OS")
	local oBack = Session.Restore(o:Snapshot(), function() return false end)
	check("an open session keeps the answers and stays open", oBack.state == "open" and oBack.groups[1].entries["ann"].answer == "OS" and oBack.groups[1].result == nil)
	check("and still takes answers", oBack:Answer(1, "Bob", "MS") == true)
	check("a bad snapshot gives nothing", Session.Restore(nil) == nil and Session.Restore({}) == nil and Session.Restore({ items = {}, groups = {} }) == nil)
	check("a name with strange text in the saved lines is skipped, not an error", Session.Restore({ state = "open", items = { 1 }, groups = { { itemID = 1, packed = "\n\t\t\nAnn\tNOPE\t\t\nBob\tMS\t\t" } } }, function() return false end).groups[1].order[1] == "bob")
end

if failed > 0 then
	print(failed .. " failed")
	os.exit(1)
end
print("ALL OK")
