-- Offline test of SoftRes/Rules.lua (who wins, ties and rerolls). Run from the ArbiterSoftReserve folder:  lua Tests/rules_test.lua

local failed = 0
local function check(name, ok)
	if not ok then
		failed = failed + 1
		print("FAIL: " .. name)
	end
end

local ASR = {}
assert(loadfile("SoftRes/Rules.lua"))("ArbiterSoftReserve", ASR)
local SoftRes = ASR.SoftRes

local function entry(name, answer, roll, reserved)
	return { name = name, answer = answer, roll = roll, reserved = reserved or false }
end
local function names(winners)
	local out = {}
	for _, w in ipairs(winners) do out[#out + 1] = w.name end
	table.sort(out)
	return table.concat(out, ",")
end

local one = SoftRes.Resolve({ copies = 1, entries = {
	entry("Allemano", "MS", 40, true), entry("Erik", "MS", 90, true), entry("Kaelis", "MS", 99, false),
} })
check("the highest roll among the reservers wins", names(one.winners) == "Erik" and one.winners[1].via == "SR" and #one.ties == 0)
check("a higher roll without a reserve does not beat a reserver", one.winners[1].roll == 90)

local passed = SoftRes.Resolve({ copies = 1, entries = {
	entry("Allemano", "PASS", nil, true), entry("Kaelis", "MS", 30, false), entry("Veyra", "OS", 95, false),
} })
check("a reserver who passed is out, and the item is open", names(passed.winners) == "Kaelis" and passed.winners[1].via == "MS")

local ms = SoftRes.Resolve({ copies = 1, entries = {
	entry("Kaelis", "OS", 99, false), entry("Veyra", "MS", 5, false),
} })
check("MS comes before OS whatever the rolls", names(ms.winners) == "Veyra")
local os_ = SoftRes.Resolve({ copies = 1, entries = { entry("Kaelis", "OS", 10, false), entry("Veyra", "OS", 60, false) } })
check("with only OS the highest OS roll wins", names(os_.winners) == "Veyra" and os_.winners[1].via == "OS")

local tier = SoftRes.Resolve({ copies = 3, entries = {
	entry("A", "MS", 11, true), entry("B", "MS", 92, true), entry("C", "MS", 55, true), entry("D", "MS", 78, true), entry("E", "MS", 3, true),
} })
check("three copies and five reservers: the three highest rolls win", names(tier.winners) == "B,C,D" and #tier.ties == 0 and tier.unclaimed == 0)

local leftover = SoftRes.Resolve({ copies = 3, entries = {
	entry("A", "MS", 11, true), entry("B", "MS", 92, true), entry("K", "MS", 70, false), entry("L", "MS", 80, false), entry("O", "OS", 99, false),
} })
check("copies left over go to the open MS rolls, highest first", names(leftover.winners) == "A,B,L")
local more = SoftRes.Resolve({ copies = 4, entries = {
	entry("A", "MS", 11, true), entry("K", "MS", 70, false), entry("O", "OS", 99, false), entry("P", "OS", 5, false),
} })
check("and then to OS", names(more.winners) == "A,K,O,P" and more.unclaimed == 0)
local unclaimed = SoftRes.Resolve({ copies = 3, entries = { entry("A", "MS", 11, true) } })
check("copies nobody wants are counted", names(unclaimed.winners) == "A" and unclaimed.unclaimed == 2)
local nobody = SoftRes.Resolve({ copies = 1, entries = { entry("A", "PASS", nil, false) } })
check("an item everybody passed has no winner", #nobody.winners == 0 and nobody.unclaimed == 1)
check("a reserver who answered OS still counts as a reserver", names(SoftRes.Resolve({ copies = 1, entries = {
	entry("A", "OS", 10, true), entry("K", "MS", 99, false) } }).winners) == "A")

-- Ties wait for a reroll
local tie = SoftRes.Resolve({ copies = 1, entries = {
	entry("A", "MS", 80, true), entry("B", "MS", 80, true), entry("C", "MS", 20, true),
} })
check("a tie for the only copy is not decided", #tie.winners == 0 and #tie.ties == 1 and tie.ties[1].slots == 1 and #tie.ties[1].names == 2)
check("it names the players who tied", table.concat(tie.ties[1].names, ",") == "A,B" and tie.ties[1].via == "SR")

local edge = SoftRes.Resolve({ copies = 3, entries = {
	entry("A", "MS", 90, true), entry("B", "MS", 60, true), entry("C", "MS", 60, true), entry("D", "MS", 60, true), entry("E", "MS", 10, true),
} })
check("a tie at the edge: those above it win, the rest roll again", names(edge.winners) == "A" and edge.ties[1].slots == 2 and #edge.ties[1].names == 3)

local fits = SoftRes.Resolve({ copies = 2, entries = { entry("A", "MS", 60, true), entry("B", "MS", 60, true), entry("C", "MS", 10, true) } })
check("a tie that fits in the copies is no tie", names(fits.winners) == "A,B" and #fits.ties == 0)

-- Reroll: rolls again for the tied players only, in a fixed order for the test
local entries = { entry("A", "MS", 80, true), entry("B", "MS", 80, true), entry("C", "MS", 20, true) }
local queue = { 30, 70 }
local function fake() return table.remove(queue, 1) end
SoftRes.Reroll(entries, tie.ties[1].names, fake)
check("a reroll gives the tied players a new roll", #entries[1].rerolls == 1 and #entries[2].rerolls == 1 and entries[3].rerolls == nil)
local after = SoftRes.Resolve({ copies = 1, entries = entries })
check("the new roll breaks the tie", names(after.winners) == "B" and #after.ties == 0)
local again = { entry("A", "MS", 80, true), entry("B", "MS", 80, true) }
queue = { 50, 50, 10, 90 }
SoftRes.Reroll(again, { "A", "B" }, fake)
check("the same reroll twice is a tie again", #SoftRes.Resolve({ copies = 1, entries = again }).ties == 1)
SoftRes.Reroll(again, { "A", "B" }, fake)
check("and another reroll decides it", names(SoftRes.Resolve({ copies = 1, entries = again }).winners) == "B")

-- Rolling for everybody who answered
local fresh = { entry("A", "MS", nil, true), entry("B", "PASS", nil, false), entry("C", "OS", 33, false) }
queue = { 44 }
check("everybody who answered and has no roll gets one", SoftRes.RollAll(fresh, fake) == 1 and fresh[1].roll == 44 and fresh[2].roll == nil and fresh[3].roll == 33)
local real = SoftRes.Roll()
check("a real roll is between 1 and 100", real >= 1 and real <= 100)

if failed > 0 then
	print(failed .. " failed")
	os.exit(1)
end
print("ALL OK")
