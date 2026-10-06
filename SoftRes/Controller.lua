-- SoftRes / Controller: the one soft reserve session ASR is running, and the texts the session window shows.
-- Plain data and functions (no frames), so it can be tested outside the game. Until Arbiter Loot Council
-- offers the small API (docs/api-sketch.md) the answers do not come from the raid: a test session is filled
-- with made-up players next to the real reservers, so the whole flow (Resolve, Reroll, Accept) can be tried
-- on one computer.

local _, ASR = ...

local SoftRes = ASR.SoftRes or {}
ASR.SoftRes = SoftRes

local Controller = {}
SoftRes.Controller = Controller

Controller.TEST_PLAYERS = 4

-- A line in the Allemano Hub's activity log (it ends up in the Hub's report), when the Hub is installed.
function Controller.HubLog(text)
	if type(_G.AllemanoHubLog) == "function" then pcall(_G.AllemanoHubLog, "ASR", text) end
	-- the same line is kept with the session, so the results can say what happened (rolled, rerolled, started over)
	if Controller.live and SoftRes.History and SoftRes.History.AddEvent then SoftRes.History.AddEvent(Controller.live, text) end
end

local VIA = { SR = "Soft reserve", MS = "Main spec", OS = "Off spec" }

-- The item IDs in a command line: links (item:12345) first, else plain numbers. Returns a list.
function Controller.ParseItemIDs(text)
	local ids = {}
	text = tostring(text or "")
	for id in text:gmatch("item:(%d+)") do ids[#ids + 1] = tonumber(id) end
	if #ids == 0 then
		for id in text:gmatch("%f[%d](%d+)%f[%D]") do ids[#ids + 1] = tonumber(id) end
	end
	return ids
end

-- The items of the loaded list, each once, and the first one that two players reserved twice (two copies make
-- a tie possible).
function Controller.ItemsOfList()
	local list = SoftRes:GetList()
	local ids = {}
	if not list then return ids end
	for itemID in pairs(list.reserves) do ids[#ids + 1] = itemID end
	table.sort(ids)
	for i, itemID in ipairs(ids) do
		if #list.reserves[itemID] >= 2 then
			table.insert(ids, i + 1, itemID)
			break
		end
	end
	return ids
end

-- Starts a session on the item IDs (one entry per slot; the same ID twice = two copies).
function Controller:Start(itemIDs)
	local items = {}
	for _, itemID in ipairs(itemIDs) do items[#items + 1] = { itemID = itemID } end
	if #items == 0 then return nil, "There are no items." end
	self.session = SoftRes.Session.New(items)
	self.live = nil -- set by the bridge when ALC runs the session
	self.wasLive = nil
	Controller.HubLog(("Soft reserve session started, %d items"):format(#items))
	return self.session
end

-- Fills the session with answers: the players who reserved an item say MS (now and then OS, which the rules
-- do not care about), and a few made-up players answer MS, OS or Pass. `random` is for the tests.
function Controller:FillTest(random)
	local session = self.session
	if not session then return false end
	random = random or math.random
	local choices = { "MS", "OS", "PASS" }
	for _, group in ipairs(session.groups) do
		local slot = group.slots[1]
		for _, entry in ipairs(SoftRes:GetReservers(group.itemID)) do
			session:Answer(slot, entry.name, random(1, 5) == 1 and "OS" or "MS")
		end
		for i = 1, Controller.TEST_PLAYERS do
			session:Answer(slot, "Tester" .. i, choices[random(1, 3)])
		end
	end
	return true
end

-- What the item row shows: how many answered what while the session is open, the outcome after Resolve.
function Controller:GroupInfo(group)
	local session = self.session
	local slot = group.slots[1]
	local info = { itemID = group.itemID, copies = group.copies, slot = slot }
	local counts = session:Counts(slot)
	info.counts = counts
	if session.state == "open" or not group.result then
		-- "SR 1/2": how many of those who reserved the item have answered
		local reservers = self:Reservers(group)
		local answered = 0
		for _, reserver in ipairs(reservers) do if reserver.answered then answered = answered + 1 end end
		info.waiting = #reservers - answered
		local sr = #reservers > 0 and ("SR %d/%d · "):format(answered, #reservers) or ""
		info.status = sr .. ("MS %d · OS %d · Pass %d"):format(counts.MS, counts.OS, counts.PASS)
		return info
	end
	local result = group.result
	local names = {}
	for _, w in ipairs(result.winners) do names[#names + 1] = w.name end
	if #result.ties > 0 then
		info.tied = true
		info.status = "Tie: " .. table.concat(result.ties[1].names, ", ")
	elseif #names > 0 then
		info.status = "Winner: " .. table.concat(names, ", ") .. (result.unclaimed > 0 and (" (+" .. result.unclaimed .. " unclaimed)") or "")
	else
		info.status = "Nobody wants it"
	end
	-- handed to the disenchanter after Accept
	local de = group.disenchanted
	if de and #de > 0 and not info.tied then
		if #names > 0 then
			info.status = "Winner: " .. table.concat(names, ", ") .. " \194\183 Disenchanted: " .. table.concat(de, ", ")
		else
			info.status = "Disenchanted by " .. table.concat(de, ", ")
		end
	end
	return info
end

-- "87" or "87 > 64, 91" (the roll, then the rerolls).
function Controller.RollText(row)
	if row.roll == nil then return "-" end
	local text = tostring(row.roll)
	if row.rerolls and #row.rerolls > 0 then
		local more = {}
		for _, r in ipairs(row.rerolls) do more[#more + 1] = tostring(r) end
		text = text .. " > " .. table.concat(more, ", ")
	end
	return text
end

-- The outcome of a row as words.
function Controller.OutcomeText(row)
	if row.disenchant then return "Disenchanted" end
	if row.outcome == "won" then return "Won (" .. (VIA[row.via] or tostring(row.via)) .. ")" end
	if row.outcome == "tied" then return "Tied" end
	if row.outcome == "passed" then return "Passed" end
	return row.roll and "Lost" or ""
end

function Controller:State()
	return self.session and self.session.state or nil
end

-- The buttons of the window: what can be pressed now.
function Controller:Can()
	local session = self.session
	if not session then return {} end
	local state = session.state
	local tied = false
	for _, group in ipairs(session.groups) do
		if group.result and #group.result.ties > 0 then tied = true end
	end
	return {
		resolve = state == "open",
		reroll = state == "resolved" and tied,
		accept = state == "resolved" and not tied,
		reopen = state == "resolved",
	}
end

-- The chat lines for an accepted result. `nameOf(itemID)` gives the item's name (a link in the game).
function Controller.AwardLines(awards, unclaimed, slots, nameOf)
	local lines = {}
	for _, a in ipairs(awards) do
		lines[#lines + 1] = ("%s -> %s (%s, roll %s)"):format(nameOf(a.itemID), a.name, VIA[a.via] or tostring(a.via), tostring(a.roll or "-"))
	end
	for _, slot in ipairs(unclaimed) do
		lines[#lines + 1] = ("%s: nobody wants it"):format(nameOf(slots[slot]))
	end
	return lines
end

-- The loot master presses Accept. Returns the chat lines, or nil and a message.
function Controller:Accept(nameOf)
	local session = self.session
	if not session then return nil, "There is no session." end
	local awards, unclaimed = session:Accept()
	Controller.HubLog(awards and ("Result accepted, %d awarded, %d unclaimed"):format(#awards, #(unclaimed or {})) or "Accept refused")
	self.awards, self.unclaimed = awards, unclaimed -- for the loot master's "Award all" (see Bridge)
	self:Save()
	if not awards then return nil, unclaimed end
	local slots = {}
	for _, group in ipairs(session.groups) do
		for _, slot in ipairs(group.slots) do slots[slot] = group.itemID end
	end
	return Controller.AwardLines(awards, unclaimed, slots, nameOf or tostring)
end

-- The rows of an item for the window: the full result rows after Resolve (winners first, every roll), the
-- answers so far before it.
function Controller:Rows(group)
	local session = self.session
	if not session or not group then return {} end
	local classOf = {}
	for _, reserver in ipairs(SoftRes:GetReservers(group.itemID)) do
		if reserver.class ~= "" then classOf[string.lower(reserver.name)] = reserver.class end
	end
	local rows
	if group.result then
		rows = session:Rows(group.slots[1])
	else
		rows = {}
		for _, key in ipairs(group.order) do
			local entry = group.entries[key]
			rows[#rows + 1] = { name = entry.name, answer = entry.answer, reserved = session.isReserver(entry.name, group.itemID) }
		end
	end
	for _, row in ipairs(rows) do row.class = classOf[string.lower(row.name)] or SoftRes.ClassOf(row.name, group.itemID) end
	-- The players who reserved the item and have not answered: first while answers are still coming in (so the
	-- loot master sees who is missing), last once the rolls are made (they did not take part).
	local waiting = {}
	for _, reserver in ipairs(self:Reservers(group)) do
		if not reserver.answered then
			waiting[#waiting + 1] = { name = reserver.name, class = reserver.class, reserved = true, waiting = true,
				outcome = group.result and "silent" or nil }
		end
	end
	-- The player the item went to for disenchanting is marked in their own row (they may have answered), or gets one.
	for _, name in ipairs(group.disenchanted or {}) do
		local found
		for _, row in ipairs(rows) do
			if SoftRes.SameCharacter(row.name, name) or SoftRes.SameCharacter(name, row.name) then found = row break end
		end
		if found then
			found.disenchant = true
		else
			rows[#rows + 1] = { name = name, answer = "PASS", outcome = "passed", disenchant = true }
		end
	end
	if group.result then
		for _, row in ipairs(waiting) do rows[#rows + 1] = row end
		return rows
	end
	for _, row in ipairs(rows) do waiting[#waiting + 1] = row end
	return waiting
end

-- ---------------------------------------------------------------------------
-- Surviving a /reload: a session that runs in Arbiter Loot Council is kept in ASR_DB (answers, rolls, the state, the
-- accepted awards and who disenchanted what), and taken back when ALC restores the same session.
-- ---------------------------------------------------------------------------
function Controller:Save()
	ASR.db = ASR.db or {}
	if not (self.live and self.session) then ASR.db.saved = nil return end
	local disenchanted = {}
	for _, group in ipairs(self.session.groups) do
		if group.disenchanted and #group.disenchanted > 0 then
			disenchanted[#disenchanted + 1] = { itemID = group.itemID, names = group.disenchanted }
		end
	end
	ASR.db.saved = {
		sid = self.live, savedAt = time(), session = self.session:Snapshot(),
		awards = self.awards, unclaimed = self.unclaimed, disenchanted = disenchanted,
	}
end

-- Saves in a moment (many changes come at once); at once where there is no timer.
function Controller:MarkDirty()
	if not (self.live and self.session) then return end
	if C_Timer and C_Timer.After then
		if self.saving then return end
		self.saving = true
		C_Timer.After(1, function()
			self.saving = nil
			self:Save()
		end)
	else
		self:Save()
	end
end

-- Takes back the saved session when it is the one ALC runs (the same session id). Returns true when it did.
function Controller:Restore(sid)
	local saved = ASR.db and ASR.db.saved
	if not (saved and sid and saved.sid == sid) then return false end
	local session = SoftRes.Session.Restore(saved.session)
	if not session then return false end
	self.session, self.live, self.wasLive = session, sid, nil
	self.awards, self.unclaimed = saved.awards, saved.unclaimed
	for _, item in ipairs(saved.disenchanted or {}) do
		local group = session.byItem[item.itemID]
		if group then group.disenchanted = item.names end
	end
	return true
end

function Controller:ForgetSaved()
	if ASR.db then ASR.db.saved = nil end
end

-- The loot master's items that nobody wanted were handed to the disenchanter: remember who, for the windows and the
-- results. Returns true when the slot is one of the session's.
function Controller:MarkDisenchanted(slot, name)
	local session = self.session
	if not session or not slot or not name then return false end
	for _, group in ipairs(session.groups) do
		for _, s in ipairs(group.slots) do
			if s == slot then
				group.disenchanted = group.disenchanted or {}
				group.disenchanted[#group.disenchanted + 1] = name
				self:MarkDirty()
				return true
			end
		end
	end
	return false
end

-- Everybody who reserved the item, once each: { { name, class, answered } }. A reserver has answered when
-- somebody of that name (a name without a surname matches every character with it) said MS, OS or Pass.
function Controller:Reservers(group)
	local list, seen = {}, {}
	if not group then return list end
	for _, reserver in ipairs(SoftRes:GetReservers(group.itemID)) do
		local key = string.lower(reserver.name)
		if not seen[key] then
			seen[key] = true
			local answered = false
			for _, k in ipairs(group.order) do
				if SoftRes.SameCharacter(reserver.name, group.entries[k].name) then answered = true break end
			end
			list[#list + 1] = { name = reserver.name, class = (reserver.class ~= "" and reserver.class) or nil, answered = answered }
		end
	end
	return list
end
