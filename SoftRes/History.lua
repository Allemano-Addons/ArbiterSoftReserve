-- SoftRes / History: what every soft reserve session decided, kept between sessions so /asr results can show who got
-- what and what everybody rolled. Everybody with ASR keeps it for themselves, from the results Arbiter Loot Council
-- sends to the whole group (so it is what the players saw, rolls and all); the loot master records the same rows
-- when he sends them. Plain data and functions (no frames), so it can be tested outside the game.
--
-- A session: { sid, time, lm, items = { [item number] = { itemID, state, packed } } }. A row is what ALC's result holds:
-- { name, answer, roll, rerolls, outcome = "won" | "tied" | "lost" | "passed", via, reserved, silent }.
--
-- The rows of an item are kept as one short text (`packed`, one line per row, fields split by tabs), not as a table per
-- row: a big raid is 25 items x 40 players x 15 sessions, and tables cost about ten times as much memory (and
-- SavedVariables size) as the text. History.Rows(item) gives the rows back as tables; older saves that still hold
-- `rows` are read as they are.

local _, ASR = ...

local SoftRes = ASR.SoftRes or {}
ASR.SoftRes = SoftRes

local History = {}
SoftRes.History = History

History.MAX_SESSIONS = 15
History.MAX_ROWS = 60

local strlower = string.lower

local function sessions()
	ASR.db = ASR.db or {}
	ASR.db.history = ASR.db.history or {}
	return ASR.db.history
end

local function copyRows(rows)
	local out = {}
	for i, r in ipairs(rows or {}) do
		if i > History.MAX_ROWS then break end
		local rerolls
		if r.rerolls and #r.rerolls > 0 then
			rerolls = {}
			for j, n in ipairs(r.rerolls) do rerolls[j] = n end
		end
		out[i] = {
			name = r.name, answer = r.answer, roll = r.roll, rerolls = rerolls, outcome = r.outcome,
			via = r.via, reserved = r.reserved or nil, silent = r.silent or nil, disenchant = r.disenchant or nil,
		}
	end
	return out
end

local strfind, strsub, tonumber = string.find, string.sub, tonumber

-- One row as a line: name, answer, roll, rerolls (comma-separated), outcome, via, flags (r = reserved, s = silent).
local function packRow(r)
	local rerolls = ""
	if r.rerolls and #r.rerolls > 0 then rerolls = table.concat(r.rerolls, ",") end
	return table.concat({
		r.name or "", r.answer or "", r.roll and tostring(r.roll) or "", rerolls, r.outcome or "", r.via or "",
		(r.reserved and "r" or "") .. (r.silent and "s" or "") .. (r.disenchant and "d" or ""),
	}, "\t")
end

local function pack(rows)
	local lines = {}
	for i, r in ipairs(rows) do lines[i] = packRow(r) end
	return table.concat(lines, "\n")
end

local function splitTabs(line)
	local fields, from = {}, 1
	while true do
		local at = strfind(line, "\t", from, true)
		if not at then
			fields[#fields + 1] = strsub(line, from)
			break
		end
		fields[#fields + 1] = strsub(line, from, at - 1)
		from = at + 1
	end
	return fields
end

local function unpack(packed)
	local rows = {}
	if type(packed) ~= "string" or packed == "" then return rows end
	for line in (packed .. "\n"):gmatch("(.-)\n") do
		if line ~= "" then
			local f = splitTabs(line)
			local rerolls
			if f[4] and f[4] ~= "" then
				rerolls = {}
				for n in f[4]:gmatch("[^,]+") do rerolls[#rerolls + 1] = tonumber(n) end
			end
			local flags = f[7] or ""
			rows[#rows + 1] = {
				name = f[1], answer = f[2] ~= "" and f[2] or nil, roll = tonumber(f[3]), rerolls = rerolls,
				outcome = f[5] ~= "" and f[5] or nil, via = f[6] ~= "" and f[6] or nil,
				reserved = flags:find("r", 1, true) and true or nil, silent = flags:find("s", 1, true) and true or nil,
				disenchant = flags:find("d", 1, true) and true or nil,
			}
		end
	end
	return rows
end

-- The rows of an item of a session, as a list of tables (a new list every time).
function History.Rows(item)
	if not item then return {} end
	if item.rows then return item.rows end -- an older save
	return unpack(item.packed)
end

-- Remembers the result of one item of a session (the latest one wins). An item with no rows is a result that was
-- taken back (Reopen): it is forgotten. The oldest sessions go when there are more than MAX_SESSIONS.
function History.Record(sid, item, itemID, state, rows, when, lm)
	if not sid or not item or not itemID then return false end
	local list = sessions()
	local session
	for _, s in ipairs(list) do
		if s.sid == sid then session = s break end
	end
	if not session then
		if not rows or #rows == 0 then return false end
		session = { sid = sid, time = when or time(), lm = lm, items = {} }
		list[#list + 1] = session
		while #list > History.MAX_SESSIONS do table.remove(list, 1) end
	end
	if not rows or #rows == 0 then
		session.items[item] = nil
	else
		session.items[item] = { itemID = itemID, state = state, packed = pack(copyRows(rows)) }
	end
	if next(session.items) == nil then
		for i, s in ipairs(list) do
			if s == session then table.remove(list, i) break end
		end
	end
	return true
end

-- The sessions, newest first.
function History.Sessions()
	local out = {}
	local list = sessions()
	for i = #list, 1, -1 do out[#out + 1] = list[i] end
	return out
end

function History.Delete(sid)
	local list = sessions()
	for i, s in ipairs(list) do
		if s.sid == sid then table.remove(list, i) return true end
	end
	return false
end

function History.Clear()
	ASR.db = ASR.db or {}
	ASR.db.history = {}
end

-- The names of the winners of a list of rows, and whether somebody is still tied.
local function winnersOf(rows)
	local names, tied = {}, false
	for _, r in ipairs(rows) do
		if r.outcome == "won" then names[#names + 1] = r.name end
		if r.outcome == "tied" then tied = true end
	end
	return names, tied
end

-- A session by item, in item order: { number, itemID, state, rows, winners, tied, rolled, silent } where `rolled` is
-- how many rolled, `silent` how many reserved the item and never answered and `disenchanted` the names the item was
-- handed to for disenchanting.
function History.ByItem(session)
	local out = {}
	if not session then return out end
	local numbers = {}
	for number in pairs(session.items) do numbers[#numbers + 1] = number end
	table.sort(numbers)
	for _, number in ipairs(numbers) do
		local item = session.items[number]
		local rows = History.Rows(item)
		local winners, tied = winnersOf(rows)
		local rolled, silent, disenchanted = 0, 0, {}
		for _, r in ipairs(rows) do
			if r.silent then silent = silent + 1 elseif r.roll then rolled = rolled + 1 end
			if r.disenchant then disenchanted[#disenchanted + 1] = r.name end
		end
		out[#out + 1] = {
			number = number, itemID = item.itemID, state = item.state, rows = rows,
			winners = winners, tied = tied, rolled = rolled, silent = silent, disenchanted = disenchanted,
		}
	end
	return out
end

-- A session by player: { name, wins, rolled, entries = { { number, itemID, answer, roll, rerolls, outcome, via,
-- reserved, silent } } }, the most wins first, then by name. A player is every name once (case does not matter).
function History.ByPlayer(session)
	local players, order = {}, {}
	for _, item in ipairs(History.ByItem(session)) do
		for _, r in ipairs(item.rows) do
			local key = strlower(r.name)
			local p = players[key]
			if not p then
				p = { name = r.name, wins = 0, rolled = 0, entries = {} }
				players[key] = p
				order[#order + 1] = p
			end
			if r.outcome == "won" then p.wins = p.wins + 1 end
			if r.roll then p.rolled = p.rolled + 1 end
			p.entries[#p.entries + 1] = {
				number = item.number, itemID = item.itemID, answer = r.answer, roll = r.roll, rerolls = r.rerolls,
				outcome = r.outcome, via = r.via, reserved = r.reserved, silent = r.silent, disenchant = r.disenchant, state = item.state,
			}
		end
	end
	table.sort(order, function(a, b)
		if a.wins ~= b.wins then return a.wins > b.wins end
		return strlower(a.name) < strlower(b.name)
	end)
	return order
end

-- Records what Arbiter Loot Council holds for an item of its running session (called when a result arrives).
function History.RecordFromALC(item)
	if not item or not (ALC and ALC.Results and ALC.Sessions and ALC.Sessions.GetSession) then return false end
	local session = ALC.Sessions:GetSession()
	local target = session and session.items and session.items[item]
	if not target then return false end
	local rows, state = ALC.Results:Get(item)
	return History.Record(session.sid, item, target.itemID, state, rows or {}, time(), session.lm)
end

function History.Init()
	if not (ALC and ALC.Events and ALC.Events.Register) then return false end
	ALC.Events.Register(History, "ALC_RESULTS_CHANGED", function(_, item) History.RecordFromALC(item) end)
	return true
end
