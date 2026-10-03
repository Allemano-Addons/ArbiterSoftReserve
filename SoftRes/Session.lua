-- SoftRes / Session: the state of one soft reserve session, as plain data and functions (no windows, no
-- messages), so that the whole flow can be tested outside the game:
--
--   open      players answer MS / OS / Pass on the items (and may change their answer)
--   resolved  the loot master pressed Resolve: everybody who answered has a roll, the rules have been
--             applied, a tie waits for Reroll
--   accepted  the loot master accepted the result: the list of awards is handed over
--
-- The items of an Arbiter Loot Council session are numbered (slots). Items with the same item ID are copies
-- of one thing (three Conqueror tokens): they form one group, are answered once and share the rolls; the
-- winners are put on the slots in order.

local _, ASR = ...

local SoftRes = ASR.SoftRes or {}
ASR.SoftRes = SoftRes

local strlower = string.lower

local Session = {}
Session.__index = Session
SoftRes.Session = Session

local VALID = { MS = true, OS = true, PASS = true }

-- `items` is the list of the session's items in slot order: { { itemID = n }, ... }.
-- `isReserver(name, itemID)` says whether a character reserved the item (the imported list by default).
function Session.New(items, isReserver)
	local self = setmetatable({
		state = "open",
		groups = {},
		byItem = {},
		slotGroup = {},
		isReserver = isReserver or function(name, itemID) return SoftRes:IsReserver(name, itemID) end,
	}, Session)
	for slot, item in ipairs(items) do
		local group = self.byItem[item.itemID]
		if not group then
			group = { itemID = item.itemID, slots = {}, entries = {}, order = {} }
			self.byItem[item.itemID] = group
			self.groups[#self.groups + 1] = group
		end
		group.slots[#group.slots + 1] = slot
		self.slotGroup[slot] = group
	end
	for _, group in ipairs(self.groups) do group.copies = #group.slots end
	return self
end

-- A player's answer to an item (any slot of its group). Returns true, or false and a message.
function Session:Answer(slot, name, answer)
	if self.state ~= "open" then return false, "The answers are closed." end
	local group = self.slotGroup[slot]
	if not group then return false, "That item is not in the session." end
	if type(name) ~= "string" or name == "" then return false, "There is no player name." end
	answer = string.upper(tostring(answer or ""))
	if not VALID[answer] then return false, "The answer has to be MS, OS or Pass." end
	local key = strlower(name)
	local entry = group.entries[key]
	if not entry then
		entry = { name = name }
		group.entries[key] = entry
		group.order[#group.order + 1] = key
	end
	entry.answer = answer
	return true
end

-- How many answered what, for an item.
function Session:Counts(slot)
	local group = self.slotGroup[slot]
	local counts = { MS = 0, OS = 0, PASS = 0, reservers = 0, copies = group and group.copies or 0 }
	if not group then return counts end
	for _, key in ipairs(group.order) do
		local entry = group.entries[key]
		counts[entry.answer] = counts[entry.answer] + 1
		if entry.answer ~= "PASS" and self.isReserver(entry.name, group.itemID) then counts.reservers = counts.reservers + 1 end
	end
	return counts
end

-- The entries of a group as a list, in the order they answered, with the reserve worked out now.
local function entriesOf(self, group)
	local list = {}
	for _, key in ipairs(group.order) do
		local entry = group.entries[key]
		entry.reserved = self.isReserver(entry.name, group.itemID)
		list[#list + 1] = entry
	end
	return list
end

local function resolveGroup(self, group)
	group.result = SoftRes.Resolve({ copies = group.copies, entries = entriesOf(self, group) })
end

-- Rolls for everybody who answered (once) and applies the rules to every item.
-- `random` is for the tests. Returns the number of items that wait for a Reroll.
function Session:Resolve(random)
	if self.state == "accepted" then return nil, "The result has been accepted." end
	local waiting = 0
	for _, group in ipairs(self.groups) do
		SoftRes.RollAll(entriesOf(self, group), random)
		resolveGroup(self, group)
		if #group.result.ties > 0 then waiting = waiting + 1 end
	end
	self.state = "resolved"
	return waiting
end

-- Rolls again for the players who tied on an item. Returns true and whether they tied again, or false and a message.
function Session:Reroll(slot, random)
	if self.state ~= "resolved" then return false, "Press Resolve first." end
	local group = self.slotGroup[slot]
	if not group then return false, "That item is not in the session." end
	local tie = group.result.ties[1]
	if not tie then return false, "Nobody tied on that item." end
	SoftRes.Reroll(entriesOf(self, group), tie.names, random)
	resolveGroup(self, group)
	return true, #group.result.ties > 0
end

-- Whether every item is decided (no tie waits).
function Session:IsDecided()
	if self.state == "open" then return false end
	for _, group in ipairs(self.groups) do
		if group.result and #group.result.ties > 0 then return false end
	end
	return true
end

-- Back to the answers: the rolls are forgotten (for when a player has to change an answer).
function Session:Reopen()
	if self.state == "accepted" then return false end
	for _, group in ipairs(self.groups) do
		for _, entry in pairs(group.entries) do
			entry.roll, entry.rerolls = nil, nil
		end
		group.result = nil
	end
	self.state = "open"
	return true
end

-- Everything the loot master would lose in a /reload, as plain data for ASR_DB: the state, the item of every slot and,
-- for every item, the answers, rolls and rerolls as one short text (one line per player, fields split by tabs). The
-- result of an item is not kept: Restore works it out again from the answers and rolls with the same rules.
function Session:Snapshot()
	local items = {}
	for slot, group in pairs(self.slotGroup) do items[slot] = group.itemID end
	local groups = {}
	for _, group in ipairs(self.groups) do
		local lines = {}
		for _, key in ipairs(group.order) do
			local e = group.entries[key]
			lines[#lines + 1] = table.concat({
				e.name, e.answer or "", e.roll and tostring(e.roll) or "", (e.rerolls and #e.rerolls > 0) and table.concat(e.rerolls, ",") or "",
			}, "\t")
		end
		groups[#groups + 1] = { itemID = group.itemID, packed = table.concat(lines, "\n"), resolved = group.result ~= nil }
	end
	return { state = self.state, items = items, groups = groups }
end

-- A session from a snapshot. A bad snapshot gives nil.
function Session.Restore(snapshot, isReserver)
	if type(snapshot) ~= "table" or type(snapshot.items) ~= "table" or #snapshot.items == 0 or type(snapshot.groups) ~= "table" then return nil end
	local items = {}
	for slot, itemID in ipairs(snapshot.items) do items[slot] = { itemID = itemID } end
	local self = Session.New(items, isReserver)
	self.state = (snapshot.state == "resolved" or snapshot.state == "accepted") and snapshot.state or "open"
	for _, saved in ipairs(snapshot.groups) do
		local group = self.byItem[saved.itemID]
		if group and type(saved.packed) == "string" then
			for line in (saved.packed .. "\n"):gmatch("(.-)\n") do
				local name, answer, roll, rerolls = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t?(.*)$")
				if name and name ~= "" and VALID[answer] then
					local key = strlower(name)
					local entry = { name = name, answer = answer, roll = tonumber(roll) }
					if rerolls and rerolls ~= "" then
						entry.rerolls = {}
						for n in rerolls:gmatch("[^,]+") do entry.rerolls[#entry.rerolls + 1] = tonumber(n) end
					end
					group.entries[key] = entry
					group.order[#group.order + 1] = key
				end
			end
			if saved.resolved then resolveGroup(self, group) end
		end
	end
	return self
end

-- Every roll of an item, for the result window that everybody sees: winners first, then those who lost,
-- then those who passed. Each row: { name, answer, roll, rerolls, reserved, outcome = "won" | "tied" | "lost" | "passed", via }.
function Session:Rows(slot)
	local group = self.slotGroup[slot]
	if not group or not group.result then return {} end
	local won, tied = {}, {}
	for _, w in ipairs(group.result.winners) do won[strlower(w.name)] = w.via end
	for _, t in ipairs(group.result.ties) do
		for _, name in ipairs(t.names) do tied[strlower(name)] = true end
	end
	local rows = {}
	for _, key in ipairs(group.order) do
		local entry = group.entries[key]
		local outcome = "lost"
		if entry.answer == "PASS" then outcome = "passed"
		elseif won[key] then outcome = "won"
		elseif tied[key] then outcome = "tied" end
		rows[#rows + 1] = {
			name = entry.name, answer = entry.answer, roll = entry.roll, rerolls = entry.rerolls,
			reserved = entry.reserved, outcome = outcome, via = won[key],
		}
	end
	local rank = { won = 1, tied = 2, lost = 3, passed = 4 }
	table.sort(rows, function(a, b)
		if rank[a.outcome] ~= rank[b.outcome] then return rank[a.outcome] < rank[b.outcome] end
		local ra, rb = a.roll or 0, b.roll or 0
		if ra ~= rb then return ra > rb end
		return a.name < b.name
	end)
	return rows
end

-- The loot master accepts: returns the awards { { slot, name, itemID, via, roll } } and the slots nobody wanted.
-- Only possible when the result is decided.
function Session:Accept()
	if self.state ~= "resolved" then return nil, "Press Resolve first." end
	if not self:IsDecided() then return nil, "A tie has to be rerolled first." end
	local awards, unclaimed = {}, {}
	for _, group in ipairs(self.groups) do
		for i, slot in ipairs(group.slots) do
			local w = group.result.winners[i]
			if w then
				awards[#awards + 1] = { slot = slot, name = w.name, itemID = group.itemID, via = w.via, roll = w.roll }
			else
				unclaimed[#unclaimed + 1] = slot
			end
		end
	end
	table.sort(awards, function(a, b) return a.slot < b.slot end)
	self.state = "accepted"
	return awards, unclaimed
end
