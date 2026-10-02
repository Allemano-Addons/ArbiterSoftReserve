-- Runs ASR's bridge against the REAL Arbiter Loot Council code (its own test harness, a fake game around it):
-- a soft reserve session is started through ALC, players answer through ALC's message handling, ASR reads the
-- answers, resolves, and hands the rolls back to ALC. Not part of the normal tests (it needs the sibling ALC repo).
--
-- Run from the ALC folder:   lua ../ArbiterSoftReserve/Tools/alc_integration.lua
package.path = "./Tests/?.lua;" .. package.path
local H = require("harness")

local failed, passed = 0, 0
local function check(name, ok)
	if ok then passed = passed + 1 else failed = failed + 1 print("FAIL: " .. name) end
end

H.setup()
H.loadAddon()
ALC:OnInitialize()
H.setupFrames()
local env = H.env
local Sessions, Council, Comm, Candidates = ALC.Sessions, ALC.Council, ALC.Comm, ALC.Candidates
local AceSerializer = LibStub("AceSerializer-3.0")
local ME = "Tester Moo"

-- The world: a party we lead, two items the game knows
local db = { [200] = "Crown of Destruction", [100] = "Band of Accuria" }
local function idOf(item) return tonumber(item) or tonumber(tostring(item):match("item:(%d+)")) end
C_Item.GetItemInfoInstant = function(item) if db[idOf(item)] then return idOf(item), "Armor", "Plate", "INVTYPE_HEAD", 133101 end end
C_Item.GetItemInfo = function(item)
	local id = idOf(item)
	if db[id] then return db[id], "|Hitem:" .. id .. "|h[" .. db[id] .. "]|h", 4, 60, 0, "Armor", "Plate", 1, "INVTYPE_HEAD", 133101 end
end
C_Item.RequestLoadItemDataByID = function() end
local units = {
	player = { "Tester", "Moo", "ROGUE" }, party1 = { "Veyra", "Moo", "WARRIOR" },
	party2 = { "Jonatan", "Moo", "PRIEST" }, party3 = { "Kaelis", "Moo", "HUNTER" },
}
UnitName = function(unit) local u = units[unit]; if u then return u[1], u[2] end end
UnitClass = function(unit) local u = units[unit]; if u then return u[3], u[3] end end
UnitIsConnected = function() return true end
H.inGroup = true
Council.GetLootMethodInfo = function() return 3 end
Council.GetLeaderName = function() return ME end
Comm.GetGroupNames = function()
	local names = {}
	for _, unit in ipairs(ALC:GroupUnits()) do
		local name = ALC:UnitFullName(unit)
		if name then names[#names + 1] = name end
	end
	return names
end
Comm:InvalidateRoster()
Council:Refresh()
ALC.Settings:GetDB().profile.council = {}
ALC.Settings:AddCouncilMember("Veyra Moo")
ALC.Settings:AddCouncilMember("Kaelis Moo")

-- ASR, loaded the way the game does it
time = os.time
local ASR = { db = {} }
for _, file in ipairs({ "Import", "Rules", "Session", "Controller", "Bridge" }) do
	assert(loadfile("../ArbiterSoftReserve/SoftRes/" .. file .. ".lua"))("ArbiterSoftReserve", ASR)
end
local SoftRes = ASR.SoftRes
local Controller, Bridge = SoftRes.Controller, SoftRes.Bridge
SoftRes:Import(table.concat({
	"Item Name,Item ID,From,Raider Name,Raider Class,Raider Spec,Raider Note,Extra Reserves,Date",
	"Crown,200,Boss,Veyra,Warrior,Fury,,0,x",
	"Crown,200,Boss,Jonatan,Priest,Holy,,0,x",
	"Band,100,Boss,Kaelis,Hunter,Marksman,,0,x",
}, "\n"))
ASR.SessionWindow = { Show = function() end, Refresh = function() end }
check("the bridge hooks into the real ALC events", Bridge.Init() == true)
check("ALC has the API ASR needs", Bridge.Available() == true)

-- Start through ALC (its real validation, the real loop-back of the message)
local ok, sid = Bridge.Start({ 200, 200, 100 })
check("ALC starts the soft reserve session", ok == true and Sessions:IsActive())
local s = Sessions:GetSession()
check("it has the mode and three answer buttons", s.mode == "SR" and #s.responses == 3 and s.responses[1].id == "MS" and s.responses[3].id == "PASS")
check("ALC does not roll when players answer", s.rolls == false)
check("each item carries who reserved it", s.items[1].extra.mark == "SR" and s.items[1].extra.markFor[1] == "Veyra" and s.items[1].extra.markFor[2] == "Jonatan" and s.items[1].extra.copies == 2 and s.items[3].extra.markFor[1] == "Kaelis")
check("ASR made its session from ALC's event", Controller.session ~= nil and Controller.live == sid and #Controller.session.groups == 2)

-- Players answer the way the game delivers it: a whisper to the loot master
local function answer(player, item, response)
	return Comm:Process(env("RESPONSE", sid, nil, { item = item, response = response, gear = {} }), "WHISPER", player)
end
check("a player answers MS", answer("Veyra Moo", 1, "MS") == true)
check("the answer is accepted by ALC's own check", Candidates:Get("Veyra Moo", 1).response == "MS")
answer("Jonatan Moo", 2, "OS")      -- answers the second copy only
answer("Kaelis Moo", 1, "MS")       -- an open MS roller on the crown
answer("Kaelis Moo", 3, "PASS")
local group = Controller.session.groups[1]
check("ASR read the answers as they came in", group.entries["veyra moo"].answer == "MS" and group.entries["jonatan moo"].answer == "OS" and group.entries["kaelis moo"].answer == "MS")
check("the pass is read too", Controller.session.groups[2].entries["kaelis moo"].answer == "PASS")
check("ALC made no roll", Candidates:Get("Veyra Moo", 1).roll == nil)

-- An answer ALC refuses never reaches ASR
check("an answer that is not MS, OS or Pass is refused by ALC", answer("Veyra Moo", 1, "BIS") == false)

-- Resolve and hand the rolls back
local queue = { 90, 30, 55 }
Controller.session:Resolve(function() return table.remove(queue, 1) end)
H.sent = {}
local pushed = Bridge.PushRolls()
check("rolls were handed to ALC", pushed > 0)
local rolledAny = false
for _, entry in pairs(group.entries) do
	if entry.roll then
		local c1 = Candidates:Get(entry.name, 1)
		local c2 = Candidates:Get(entry.name, 2)
		if (c1 and c1.roll == entry.roll) or (c2 and c2.roll == entry.roll) then rolledAny = true end
	end
end
check("the candidates in ALC have ASR's rolls", rolledAny)
local roll = false
for _, sent in ipairs(H.sent) do
	local _, e = AceSerializer:Deserialize(sent.text)
	if e and e.t == "CANDIDATE_UPDATE" and e.p.roll then roll = true end
end
check("and the council was told", roll)
check("the winners follow the rules: reservers first, two copies", #group.result.winners == 2 and group.result.winners[1].via == "SR")
-- The result goes to everybody (ALC's RESULT message; we get our own copy back)
H.sent = {}
check("ASR publishes the result", Bridge.PublishResults("resolved") == 2)
H.runTimers()
local shown, state = ALC.Results:Get(1)
check("ALC keeps the rows of the first item", shown ~= nil and state == "resolved" and #shown >= 3)
check("winners first, the reserver ahead of the open rollers", shown[1].outcome == "won" and shown[1].via == "SR")
check("a row carries the roll and the answer", shown[1].roll ~= nil and shown[1].answer ~= nil)
check("the second group is the band", ALC.Results:Get(3) ~= nil)
check("ASR can accept the result", Controller:Accept(tostring) ~= nil)
check("and the accepted result is published", Bridge.PublishResults("accepted") == 2)
H.runTimers()
check("ALC shows it as accepted", select(2, ALC.Results:Get(1)) == "accepted")

-- Award all: ASR asks once, the loot master confirms, ALC hands out every winner
H.sent = {}
check("ASR asks whether to award the winners", Bridge.RequestAwards() == true and ALC.AwardDialog:IsManyShown())
local frame = ALC.AwardDialog.manyFrame
check("the question lists a winner for each copy of the crown (nobody wanted the band: Kaelis passed)", frame.rows[1]:IsShown() and frame.rows[2]:IsShown() and not frame.rows[3]:IsShown())
check("with why they won", frame.rows[1].note:GetText():find("roll", 1, true) ~= nil)
check("nothing is awarded before the confirmation", Sessions:IsItemOpen(1) and Sessions:IsItemOpen(2))
frame.confirm.scripts.OnClick(frame.confirm)
H.runTimers()
local awardCount = 0
for _, sent in ipairs(H.sent) do
	local _, e = AceSerializer:Deserialize(sent.text)
	if e and e.t == "AWARD" then awardCount = awardCount + 1 end
end
check("both crowns were awarded through ALC", awardCount == 2)
local log = ALC.Awards:GetLog()
local winners = {}
for _, r in ipairs(log) do winners[r.winner] = true end
check("the log has the winners: the two reservers", winners["Veyra Moo"] and winners["Jonatan Moo"] and #log == 2)
check("and the band is still open", Sessions:IsItemOpen(3))

-- The session ends in ALC: ASR lets go
Sessions:Cancel("done")
check("ending the ALC session ends ASR's live mark", Controller.live == nil)

print(("alc_integration: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
