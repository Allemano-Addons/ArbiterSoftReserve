-- SoftRes / Bridge: the loot master's side of the link between ASR and Arbiter Loot Council (ALC API 2).
--
--   Start     starts a real ALC session with the soft reserve options: mode "SR", the answers MS / OS / Pass,
--             no ALC roll at answer time, and for each item who reserved it (the players' windows tag those items "SR")
--   Sync      reads the answers ALC has collected into the ASR session
--   PushRolls after Resolve / Reroll: hands the rolls ASR made to ALC, so the council sees them
--   PublishResults  sends every item's rows (answers, rolls, outcomes) to the whole group, for ALC's Result window
--   RequestAwards   after Accept: asks the loot master once whether to hand out all the winners (ALC's "Award all")
--
-- ALC stays in charge of the session, the answers and the messages; ASR only decides who wins. No frames here,
-- so it can be tested outside the game against a stand-in for ALC.

local _, ASR = ...

local SoftRes = ASR.SoftRes or {}
ASR.SoftRes = SoftRes

local Bridge = {}
SoftRes.Bridge = Bridge

Bridge.REQUIRED_API = 5
Bridge.MODE = "SR"
Bridge.NAME = "Soft Reserve" -- shown in the titles of ALC's windows for this kind of session
Bridge.COLOR = "9B7BFF"      -- ASR's purple: the mark and the accent in those windows
Bridge.MAX_LIST = 40 -- the longest list of names ALC accepts in an item's data

local function responses()
	return {
		{ id = "MS", label = "MS", color = "4caf50" },
		{ id = "OS", label = "OS", color = "ffb300" },
		{ id = "PASS", label = "Pass", color = "888888" },
	}
end

-- Whether ALC is new enough. Returns true, or false and what to tell the player.
function Bridge.Available()
	if not (ALC and ALC.HasAPI) then
		return false, "Arbiter Loot Council is too old for soft reserve sessions (it has no API yet). Update it."
	end
	if not ALC.HasAPI(Bridge.REQUIRED_API) then
		return false, "Arbiter Loot Council is too old for soft reserve sessions (it needs API " .. Bridge.REQUIRED_API .. ")."
	end
	return true
end

-- The options for ALC's Sessions:StartItems for these item IDs (one per slot; the same ID twice = two copies).
function Bridge.Options(itemIDs)
	local copies = {}
	for _, itemID in ipairs(itemIDs) do copies[itemID] = (copies[itemID] or 0) + 1 end
	local extra = {}
	for slot, itemID in ipairs(itemIDs) do
		local names = {}
		for _, reserver in ipairs(SoftRes:GetReservers(itemID)) do
			if #names < Bridge.MAX_LIST and #reserver.name >= 2 and #reserver.name <= 48 then names[#names + 1] = reserver.name end
		end
		local data = { copies = copies[itemID] }
		-- ALC tags the item "SR" in the windows of the players named in markFor (a name without a surname matches
		-- every character with that first name)
		if #names > 0 then data.mark, data.markFor = "SR", names end
		extra[slot] = data
	end
	return { mode = Bridge.MODE, modeName = Bridge.NAME, modeColor = Bridge.COLOR, responses = responses(), rolls = false, extra = extra }
end

-- Starts the session in ALC. The ASR session is made when ALC announces it (see Init). Returns true, or false
-- and a message.
function Bridge.Start(itemIDs)
	local ok, message = Bridge.Available()
	if not ok then return false, message end
	if type(itemIDs) ~= "table" or #itemIDs == 0 then return false, "There are no items." end
	return ALC.Sessions:StartItems(itemIDs, Bridge.Options(itemIDs))
end

-- ALC's Loot window offers "Start SR" next to its normal Start. It hands over the item links of the items the
-- loot master picked; the session is started here, with the soft reserve options. Returns true or false, message.
function Bridge.StartFromLinks(links)
	local ids = {}
	for _, link in ipairs(links or {}) do
		local id = tonumber(tostring(link):match("item:(%d+)")) or tonumber(link)
		if id then ids[#ids + 1] = id end
	end
	return Bridge.Start(ids)
end

-- Adds that button to ALC's Loot window (ALC API 5). Returns true, or false and why not.
function Bridge.RegisterStartMode()
	if not (ALC and ALC.RegisterStartMode and Bridge.Available()) then return false, "ALC cannot add a start button." end
	return ALC.RegisterStartMode({
		id = Bridge.MODE, label = "SR", name = Bridge.NAME, color = Bridge.COLOR,
		start = Bridge.StartFromLinks,
	})
end

-- Adds ASR's rows to ALC's window menu (the minimap button), under a "Soft Reserve" heading: Results for everybody,
-- the session window and the import box for the loot master. Returns true, or false and why not.
function Bridge.RegisterLauncherEntries()
	if not (ALC and ALC.RegisterLauncherEntry and Bridge.Available()) then return false, "ALC has no window menu to add to." end
	local function entry(id, label, icon, available, open)
		return ALC.RegisterLauncherEntry({ id = "asr-" .. id, label = label, icon = icon, section = Bridge.NAME, color = Bridge.COLOR,
			available = available, open = open })
	end
	entry("results", "Results", "summary", nil, function() ASR.ResultsWindow:Toggle() end)
	entry("session", "Session", "council", function()
		if not SoftRes.Controller.session then return false, "Needs a soft reserve session (/asr start)." end
		return true
	end, function() ASR.SessionWindow:Show() end)
	entry("import", "Import list", "note", nil, function() ASR.ImportWindow:Show() end)
	return true
end

-- Reads the answers ALC has collected into the running ASR session. A group of copies is answered on any of its
-- slots; the lowest slot with an answer counts for that player. Returns how many answers were read.
function Bridge.Sync()
	local Controller = SoftRes.Controller
	local session = Controller.session
	if not session or session.state ~= "open" or not (ALC and ALC.Candidates) then return 0 end
	local count = 0
	for _, group in ipairs(session.groups) do
		local seen = {}
		for _, slot in ipairs(group.slots) do
			for _, candidate in ipairs(ALC.Candidates:GetList(slot) or {}) do
				local key = string.lower(candidate.name)
				if not seen[key] then
					seen[key] = true
					if session:Answer(group.slots[1], candidate.name, candidate.response) then count = count + 1 end
				end
			end
		end
	end
	if count > 0 then Controller:MarkDirty() end
	return count
end

-- The roll to show for an entry: the last reroll, else the first roll.
local function shownRoll(entry)
	if entry.rerolls and #entry.rerolls > 0 then return entry.rerolls[#entry.rerolls] end
	return entry.roll
end

-- Gives ALC the rolls ASR made, so the council sees them next to the answers. Returns how many were set.
function Bridge.PushRolls()
	local Controller = SoftRes.Controller
	local session = Controller.session
	if not session or not (ALC and ALC.Candidates and ALC.Candidates.SetRoll) then return 0 end
	local count = 0
	for _, group in ipairs(session.groups) do
		for _, key in ipairs(group.order) do
			local entry = group.entries[key]
			local roll = shownRoll(entry)
			if roll then
				for _, slot in ipairs(group.slots) do
					if ALC.Candidates:SetRoll(entry.name, roll, slot) then count = count + 1 end
				end
			end
		end
	end
	return count
end

-- The rows ALC shows in its Result window, from ASR's rows of an item: only what ALC's message holds. Winners come
-- first, so a long list loses the ones who passed.
local function wireRows(rows)
	local out = {}
	for _, row in ipairs(rows) do
		if #out >= 60 then break end
		local rerolls
		if row.rerolls and #row.rerolls > 0 then
			rerolls = {}
			for i = math.max(1, #row.rerolls - 9), #row.rerolls do rerolls[#rerolls + 1] = row.rerolls[i] end
		end
		if row.waiting then
			-- reserved the item and never answered: sent as a Pass (ALC versions that do not know the flag show
			-- "Passed"), flagged so newer ones say "Did not answer"
			out[#out + 1] = { name = row.name, answer = "PASS", outcome = "passed", reserved = true, silent = true }
		else
			out[#out + 1] = {
				name = row.name, answer = row.answer, roll = row.roll, rerolls = rerolls,
				outcome = row.outcome, via = row.via, reserved = row.reserved or nil, disenchant = row.disenchant or nil,
			}
		end
	end
	return out
end

-- Sends the result of every item to the whole group (ALC API 3): `state` is "resolved" or "accepted". An item
-- that has no result yet (after Reopen) is sent with no rows, so the players' windows do not show an old result.
-- Returns how many items were sent. One message per item, sent to the first slot of a group of copies.
function Bridge.PublishResults(state)
	local Controller = SoftRes.Controller
	local session = Controller.session
	if not session or not (ALC and ALC.Results and ALC.Results.Publish) then return 0 end
	local count = 0
	for _, group in ipairs(session.groups) do
		local rows = group.result and wireRows(Controller:Rows(group)) or {}
		if ALC.Results:Publish(group.slots[1], state, rows) then
			count = count + 1
			-- the loot master keeps the same rows for /asr results (the players keep what they receive)
			if SoftRes.History and Controller.live then
				SoftRes.History.Record(Controller.live, group.slots[1], group.itemID, state, rows, time(), UnitName and UnitName("player"))
			end
		end
	end
	return count
end

local VIA = { SR = "SR", MS = "MS", OS = "OS" }

-- The items nobody wanted, as entries for ALC's "Award all" that hand them to the disenchanter from ALC's settings.
-- Empty when there are none, when the loot master turned it off (/asr disenchant off) or when ALC cannot do it; in
-- that last case the second value says why (no disenchanter set, not in the group), so the loot master is told.
function Bridge.DisenchantList()
	local list = {}
	local unclaimed = SoftRes.Controller.unclaimed or {}
	if #unclaimed == 0 then return list end
	if ASR.db and ASR.db.disenchant == false then return list end
	if not (ALC and ALC.Awards and ALC.Awards.CanDisenchant) then return list end
	local ok, why = ALC.Awards:CanDisenchant()
	if not ok then return list, why or "ALC cannot hand them to a disenchanter." end
	for _, slot in ipairs(unclaimed) do list[#list + 1] = { item = slot, disenchant = true, note = "Nobody wanted it" } end
	return list
end

-- The list ALC's AwardMany takes, from what the loot master accepted: { { item = slot, name, note } }, then the items
-- nobody wanted as { item = slot, disenchant = true } (see DisenchantList). The note says why the player won
-- ("SR, roll 87").
function Bridge.AwardList()
	local Controller = SoftRes.Controller
	local list = {}
	for _, award in ipairs(Controller.awards or {}) do
		local note = VIA[award.via] or ""
		if award.roll then note = (note ~= "" and (note .. ", ") or "") .. "roll " .. award.roll end
		list[#list + 1] = { item = award.slot, name = award.name, note = note }
	end
	for _, entry in ipairs(Bridge.DisenchantList()) do list[#list + 1] = entry end
	return list
end

-- Asks the loot master (one question, ALC's award box) whether to hand out the accepted winners. Items nobody
-- wanted are left alone. Returns true when the question was shown, or false and a message.
function Bridge.RequestAwards()
	local list = Bridge.AwardList()
	local _, whyNot = Bridge.DisenchantList()
	if whyNot and ASR.Print then
		ASR:Print("Nobody wanted " .. #(SoftRes.Controller.unclaimed or {}) .. " of the items, so they are left alone: " .. whyNot)
	end
	if #list == 0 then return false, "Nobody won anything, so there is nothing to hand out." end
	if not (ALC and ALC.AwardDialog and ALC.AwardDialog.AskMany) then
		return false, "Arbiter Loot Council is too old to hand out all the winners at once."
	end
	return ALC.AwardDialog:AskMany(list)
end

-- ALC's events: a soft reserve session that starts makes the ASR session; answers are read as they come.
-- Only the loot master runs the ASR session.
function Bridge.Init()
	if not (ALC and ALC.Events and ALC.Events.Register) then return false end
	ALC.Events.Register(Bridge, "ALC_SESSION_STARTED", function(_, alcSession)
		if not (alcSession and alcSession.mode == Bridge.MODE and alcSession.isLM) then return end
		local ids = {}
		for slot, item in ipairs(alcSession.items) do ids[slot] = item.itemID end
		local Controller = SoftRes.Controller
		-- ALC restored its session after a /reload: take ASR's side back too (the rolls are only here)
		if not (alcSession.restored and Controller:Restore(alcSession.sid)) then
			Controller:Start(ids)
			Controller.live = alcSession.sid
		end
		Bridge.Sync()
		Controller:MarkDirty()
		if ASR.SessionWindow then ASR.SessionWindow:Show() end
	end)
	-- An item handed to the disenchanter: the session window, the results and the players' windows say so
	ALC.Events.Register(Bridge, "ALC_COMM_AWARD", function(_, _, sid, p)
		local Controller = SoftRes.Controller
		local deId = ALC.Constants and ALC.Constants.DISENCHANT_ID
		if not (deId and Controller.live and Controller.live == sid and type(p) == "table" and p.response == deId) then return end
		if Controller:MarkDisenchanted(p.item, p.winner) then
			Bridge.PublishResults("accepted")
			if ASR.SessionWindow then ASR.SessionWindow:Refresh() end
		end
	end)
	ALC.Events.Register(Bridge, "ALC_CANDIDATES_CHANGED", function()
		if SoftRes.Controller.live then
			Bridge.Sync()
			if ASR.SessionWindow then ASR.SessionWindow:Refresh() end
		end
	end)
	ALC.Events.Register(Bridge, "ALC_SESSION_PAUSED", function()
		if SoftRes.Controller.live and ASR.SessionWindow then ASR.SessionWindow:Refresh() end
	end)
	ALC.Events.Register(Bridge, "ALC_SESSION_ENDED", function(_, sid)
		local Controller = SoftRes.Controller
		if Controller.live == sid then
			Controller:ForgetSaved()
			Controller.live = nil
			Controller.wasLive = true -- the window says the session has ended, not that it was a test
			if ASR.SessionWindow then ASR.SessionWindow:Refresh() end
		end
	end)
	return true
end
