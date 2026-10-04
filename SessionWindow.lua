-- SessionWindow: the loot master's window for a soft reserve session. The items on the left (with what was
-- answered, or who won), every player's answer and roll for the selected item on the right, and the buttons
-- Resolve / Reroll / Accept. The same rows are what the result window will show everybody once Arbiter Loot
-- Council can carry them (docs/api-sketch.md).
--
-- The look is Arbiter Loot Council's: ASR needs ALC anyway, so it builds the window from ALC's own widgets
-- (ALC.UI: rounded panels, text, buttons, scroll bars) and so follows ALC's font and window size settings.
-- Only the mark is ASR's own (purple instead of green).
local _, ASR = ...

local SessionWindow = {}
ASR.SessionWindow = SessionWindow

local Controller = function() return ASR.SoftRes.Controller end

-- The window is as tall as its content: one row per item (up to ITEM_ROWS) and per player of the selected item
-- (from MIN_PLAYER_ROWS up to PLAYER_ROWS); a longer list scrolls.
local WIDTH, PAD = 780, 16
local HEADER_H = 40
local LIST_W, ITEM_H, ITEM_ROWS, ITEM_GAP = 240, 46, 8, 4
local PLAYER_H, PLAYER_ROWS, MIN_PLAYER_ROWS = 24, 12, 3
local TOP_H = HEADER_H + 40 -- header and the line under it, where the lists start
local PLAYERS_HEAD_H = 72   -- the item's name, its status line and the column heads, above the player rows
local FOOTER_H = 70
local COL = { name = 12, answer = 170, roll = 226, result = 330 }
local itemVisible, playerVisible = 1, MIN_PLAYER_ROWS
local PURPLE = { 0.61, 0.48, 1, 1 }
local MEDIA = "Interface\\AddOns\\ArbiterSoftReserve\\Media\\"

local frame, UI, c
local stateTag, timerText, banner, header, headerSub
local itemRows, playerRows = {}, {}
local buttons = {}
local itemBar, playerBar, itemList, playerRowsFrame
local view = "session" -- "session" or "trades" (Arbiter Loot Council's trade queue)
local rightPane, tradeFrame, tradeBar, tradeEmpty
local tabButtons, tradeRows = {}, {}
local tradeOffset, tradeVisible = 0, 1
local TRADE_ROWS, TRADE_H, TRADE_GAP = 8, 46, 4
local selected, itemOffset, playerOffset = 1, 0, 0
local retries = 0 -- how many times the window has looked again for item names the game did not have yet

-- ---------------------------------------------------------------------------
-- Items
-- ---------------------------------------------------------------------------

local function itemInfo(itemID)
	local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	local name, quality, icon
	if getInfo then
		local n, _, q, _, _, _, _, _, _, i = getInfo(itemID)
		name, quality, icon = n, q, i
	end
	if not icon then
		local getIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
		icon = getIcon and getIcon(itemID) or nil
	end
	if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
	return name or ("Item " .. itemID), quality, icon, name ~= nil
end

local function itemNameForChat(itemID)
	local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	local link = getInfo and select(2, getInfo(itemID))
	return link or ("item " .. itemID)
end

local function buildItemRow(parent, index)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(ITEM_H)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * (ITEM_H + ITEM_GAP))
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -(index - 1) * (ITEM_H + ITEM_GAP))
	row:RegisterForClicks("LeftButtonUp")
	row.bg = UI.NewFill(row, 6)
	row.border = UI.AddBorder(row, c.border, 1, 6)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(32, 32)
	row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
	row.name = UI.NewText(row, 13, c.text)
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -2)
	row.name:SetPoint("RIGHT", row, "RIGHT", -40, 0)
	row.status = UI.NewText(row, 12, c.muted)
	row.status:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 2)
	row.status:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	row.copies = UI.NewText(row, 13, PURPLE, "RIGHT")
	row.copies:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -6)
	local function look(self, hover)
		if self.index == selected then
			UI.SetTextureColor(self.bg, c.goldTint)
			self.border:SetColor(c.gold)
		else
			UI.SetTextureColor(self.bg, hover and c.panelHover or c.panel)
			self.border:SetColor(hover and c.gold or c.border)
		end
	end
	row.look = look
	row:SetScript("OnEnter", function(self)
		look(self, true)
		if GameTooltip and self.itemID then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink("item:" .. self.itemID)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function(self)
		look(self, false)
		if GameTooltip then GameTooltip:Hide() end
	end)
	row:SetScript("OnClick", function(self)
		selected = self.index
		playerOffset = 0
		SessionWindow:Refresh()
	end)
	return row
end

local function paintItemRow(row, group, index)
	row.index = index
	row.itemID = group.itemID
	local info = Controller():GroupInfo(group)
	local name, quality, icon = itemInfo(group.itemID)
	row.name:SetText(name)
	local q = UI.QualityColor(quality)
	row.name:SetTextColor(q[1], q[2], q[3], 1)
	if icon then row.icon:SetTexture(icon) else row.icon:SetColorTexture(0.2, 0.2, 0.24, 1) end
	row.status:SetText(info.status)
	-- amber while somebody who reserved the item has not answered
	local sc = (info.tied or (info.waiting or 0) > 0) and c.gold or c.muted
	row.status:SetTextColor(sc[1], sc[2], sc[3], 1)
	row.copies:SetText(group.copies > 1 and ("x" .. group.copies) or "")
	row.look(row, false)
end

-- ---------------------------------------------------------------------------
-- Players
-- ---------------------------------------------------------------------------

local function buildPlayerRow(parent, index)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(PLAYER_H)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * PLAYER_H)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -(index - 1) * PLAYER_H)
	row.line = row:CreateTexture(nil, "BORDER")
	row.line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 0)
	row.line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 0)
	row.line:SetHeight(1)
	UI.SetTextureColor(row.line, c.border, 0.5)
	row.tag = UI.NewText(row, 11, PURPLE)
	row.tag:SetPoint("LEFT", row, "LEFT", COL.name, 0)
	row.name = UI.NewText(row, 13, c.text)
	row.name:SetPoint("LEFT", row, "LEFT", COL.name + 26, 0)
	row.name:SetWidth(COL.answer - COL.name - 34)
	row.answer = UI.NewText(row, 12, c.muted)
	row.answer:SetPoint("LEFT", row, "LEFT", COL.answer, 0)
	row.roll = UI.NewText(row, 13, c.text)
	row.roll:SetPoint("LEFT", row, "LEFT", COL.roll, 0)
	row.result = UI.NewText(row, 13, c.muted)
	row.result:SetPoint("LEFT", row, "LEFT", COL.result, 0)
	return row
end

local ANSWER = { MS = "MS", OS = "OS", PASS = "Pass" }
local GREEN = { 0.30, 0.75, 0.40, 1 }

local function paintPlayerRow(row, data)
	if not data then row:Hide() return end
	row:Show()
	row.tag:SetText(data.reserved and "SR" or "")
	row.name:SetText(data.name)
	local nc = data.class and UI.ClassColor(string.upper((data.class:gsub("[^%a]", "")))) or c.text
	row.name:SetTextColor(nc[1], nc[2], nc[3], 1)
	if data.waiting then
		-- reserved the item, has not answered: amber while answers come in, red once the rolls are made
		local silent = data.outcome == "silent"
		local wc = silent and c.danger or c.gold
		row.answer:SetText(silent and "None" or "Waiting")
		row.answer:SetTextColor(wc[1], wc[2], wc[3], 1)
		row.roll:SetText("-")
		row.result:SetText(silent and "Did not answer, no roll" or "Has not answered yet")
		row.result:SetTextColor(wc[1], wc[2], wc[3], 1)
		return
	end
	row.answer:SetText(ANSWER[data.answer] or "")
	row.answer:SetTextColor(c.muted[1], c.muted[2], c.muted[3], 1)
	row.roll:SetText(Controller().RollText(data))
	row.result:SetText(Controller().OutcomeText(data))
	local rc = c.muted
	if data.outcome == "won" then rc = GREEN elseif data.outcome == "tied" then rc = c.gold elseif data.disenchant then rc = PURPLE end
	row.result:SetTextColor(rc[1], rc[2], rc[3], 1)
end

-- ---------------------------------------------------------------------------
-- Refresh
-- ---------------------------------------------------------------------------

local lastPhase -- "accepted" or "finishing" while the session is accepted (see UpdateTimer)
local STATE_TEXT = { open = "WAITING FOR ANSWERS", resolved = "RESOLVED", accepted = "ACCEPTED" }
local BANNER = {
	open = "Answers come in as the players give them. Press Resolve when the time is up.",
	resolved = "Rolled. Reroll ties if there are any, then Accept result.",
	accepted = "Accepted. Award all hands out the winners.",
	finishing = "All awarded. The session closes by itself; Close session ends it now.",
}

-- ---------------------------------------------------------------------------
-- The trade queue (Arbiter Loot Council's): the items that were awarded and still have to be handed to the winner
-- ---------------------------------------------------------------------------

local function buildTradeRow(parent, index)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(TRADE_H)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * (TRADE_H + TRADE_GAP))
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -(index - 1) * (TRADE_H + TRADE_GAP))
	row.bg = UI.NewFill(row, 6)
	UI.SetTextureColor(row.bg, c.panel)
	row.border = UI.AddBorder(row, c.border, 1, 6)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(32, 32)
	row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
	row.name = UI.NewText(row, 13, c.text)
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -1)
	row.name:SetWidth(300)
	row.sub = UI.NewText(row, 12, c.muted)
	row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 1)
	row.sub:SetWidth(380)
	row.done = UI.NewButton(row, 74, 28, "Done", function()
		if row.entryId then ALC.Trades:MarkDone(row.entryId) end
	end)
	row.done:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	row.trade = UI.NewButton(row, 74, 28, "Trade", function()
		if not row.entryId then return end
		local ok, message = ALC.Trades:StartTrade(row.entryId)
		if not ok and message then ASR:Print(message) end
	end)
	row.trade:SetPoint("RIGHT", row.done, "LEFT", -6, 0)
	row:SetScript("OnEnter", function(self)
		if GameTooltip and self.itemString then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(self.itemString)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	row:EnableMouse(true)
	return row
end

local function pendingTrades()
	if not (ALC and ALC.Trades and ALC.Trades.GetPending) then return {} end
	return ALC.Trades:GetPending()
end

local function renderTrades()
	local list = pendingTrades()
	tradeVisible = math.max(1, math.min(#list, TRADE_ROWS))
	tradeOffset = math.max(0, math.min(tradeOffset, math.max(0, #list - tradeVisible)))
	for i, row in ipairs(tradeRows) do
		local entry = list[i + tradeOffset]
		if entry and i <= tradeVisible then
			local display = ALC.LootDetection:GetItemDisplay(entry)
			row.entryId, row.itemString = entry.id, entry.itemString
			row.icon:SetTexture(display.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			local q = UI.QualityColor(display.quality)
			row.name:SetTextColor(q[1], q[2], q[3], 1)
			row.name:SetText(display.name or "...")
			local text = "Winner: " .. tostring(entry.winner)
			local left = ALC.LootDetection:GetTradeTimeLeft(entry)
			if left and ALC.LootWindow and ALC.LootWindow.FormatTradeTime then
				text = text .. "   BoP " .. ALC.LootWindow.FormatTradeTime(left)
			end
			row.sub:SetText(text)
			row:Show()
		else
			row.entryId, row.itemString = nil, nil
			row:Hide()
		end
	end
	tradeBar:Update(#list, tradeVisible, tradeOffset)
	tradeEmpty:SetShown(#list == 0)
	frame:SetHeight(TOP_H + (#list == 0 and 60 or tradeVisible * (TRADE_H + TRADE_GAP)) + FOOTER_H)
	tradeFrame:SetHeight(tradeVisible * (TRADE_H + TRADE_GAP))
end

-- Which of the two views is shown: the session or the trade queue.
local function applyView()
	local trades = view == "trades"
	itemList:SetShown(not trades)
	rightPane:SetShown(not trades)
	tradeFrame:SetShown(trades)
	if not trades then tradeEmpty:Hide() end -- its text belongs to the trade view only
	for _, button in pairs(buttons) do
		if trades then button:Hide() else button:Show() end
	end
	tabButtons.session:SetSelected(not trades)
	tabButtons.trades:SetSelected(trades)
end

local function updateTradeTab()
	if not tabButtons.trades then return end
	local n = #pendingTrades()
	tabButtons.trades:SetLabel(n > 0 and ("Trade queue (" .. n .. ")") or "Trade queue")
end

-- The answer timer of the session in Arbiter Loot Council, in the header: how long the players can still answer,
-- and when it has run out, that it is time to press Resolve. Nothing once the rolls are made.
function SessionWindow:UpdateTimer()
	if not frame or not timerText then return end
	local C = Controller()
	local session = C.session
	local Sessions = ALC and ALC.Sessions
	-- After Accept the session in Arbiter Loot Council still runs: until the winners are awarded, and then for a
	-- while so that an award can be undone. Say which, so it is clear that the session is not over yet.
	if session and C.live and session.state == "accepted" and Sessions and Sessions.GetFinishLeft then
		local finish = Sessions:GetFinishLeft()
		-- the buttons and the line under the title follow this: when it changes, draw the window again
		local phase = finish and "finishing" or "accepted"
		if phase ~= lastPhase then
			lastPhase = phase
			self:Refresh()
			return
		end
		if finish then
			finish = math.ceil(finish)
			timerText:SetTextColor(GREEN[1], GREEN[2], GREEN[3], 1)
			timerText:SetText(string.format("All awarded: the session closes in %d:%02d", math.floor(finish / 60), finish % 60))
		else
			timerText:SetTextColor(c.gold[1], c.gold[2], c.gold[3], 1)
			timerText:SetText("Accepted: not awarded yet")
		end
		return
	end
	if lastPhase and not (session and C.live and session.state == "accepted") then
		lastPhase = nil
		self:Refresh()
		return
	end
	if not (session and C.live and session.state == "open" and Sessions and Sessions.GetTimeLeft) then
		timerText:SetText("")
		return
	end
	local left = Sessions:GetTimeLeft()
	if not left then
		timerText:SetTextColor(c.muted[1], c.muted[2], c.muted[3], 1)
		timerText:SetText("No time limit")
		return
	end
	left = math.ceil(left)
	local clock = string.format("%d:%02d", math.floor(left / 60), left % 60)
	if Sessions:IsPaused() then
		timerText:SetTextColor(c.danger[1], c.danger[2], c.danger[3], 1)
		timerText:SetText("Paused: " .. clock .. " left")
	elseif left <= 0 then
		timerText:SetTextColor(GREEN[1], GREEN[2], GREEN[3], 1)
		timerText:SetText("Time is up: press Resolve")
	else
		local color = left <= 15 and c.danger or c.gold
		timerText:SetTextColor(color[1], color[2], color[3], 1)
		timerText:SetText("Time left " .. clock)
	end
end

function SessionWindow:Refresh()
	if not frame or not frame:IsShown() then return end
	local C = Controller()
	local session = C.session
	applyView()
	updateTradeTab()
	if view == "trades" then
		stateTag:SetText("")
		timerText:SetText("")
		renderTrades()
		return
	end
	if not session then return end
	-- a session that has ended in Arbiter Loot Council is "ENDED", whatever ASR's own state was
	stateTag:SetText(C.wasLive and not C.live and "ENDED" or STATE_TEXT[session.state] or "")
	self:UpdateTimer()
	-- one short line for where the session is
	local line
	if C.live then
		local Sessions = ALC and ALC.Sessions
		local finishing = session.state == "accepted" and Sessions and Sessions.GetFinishLeft and Sessions:GetFinishLeft() ~= nil
		line = finishing and BANNER.finishing or BANNER[session.state] or BANNER.open
	elseif C.wasLive then
		line = "This session in Arbiter Loot Council has ended."
	else
		line = "A test: the players next to the real reservers are made up, and nothing is handed out."
	end
	banner:SetText(line)

	local groups = session.groups
	selected = math.max(1, math.min(selected, #groups))
	itemVisible = math.max(1, math.min(#groups, ITEM_ROWS))
	itemOffset = math.max(0, math.min(itemOffset, math.max(0, #groups - itemVisible)))
	for i, row in ipairs(itemRows) do
		local group = groups[i + itemOffset]
		if group and i <= itemVisible then
			row:Show()
			paintItemRow(row, group, i + itemOffset)
		else
			row:Hide()
		end
	end
	itemBar:Update(#groups, itemVisible, itemOffset)

	local group = groups[selected]
	header:SetText((itemInfo(group.itemID)))
	local info = C:GroupInfo(group)
	headerSub:SetText((group.copies > 1 and (group.copies .. " copies. ") or "1 copy. ") .. info.status)
	local rows = C:Rows(group)
	playerVisible = math.max(MIN_PLAYER_ROWS, math.min(#rows, PLAYER_ROWS))
	playerOffset = math.max(0, math.min(playerOffset, math.max(0, #rows - playerVisible)))
	for i, row in ipairs(playerRows) do paintPlayerRow(row, i <= playerVisible and rows[i + playerOffset] or nil) end
	playerBar:Update(#rows, playerVisible, playerOffset)

	-- as tall as the longer of the two lists needs
	local itemsHeight = itemVisible * (ITEM_H + ITEM_GAP)
	local playersHeight = PLAYERS_HEAD_H + playerVisible * PLAYER_H
	frame:SetHeight(TOP_H + math.max(itemsHeight, playersHeight) + FOOTER_H)
	itemList:SetHeight(itemsHeight)
	playerRowsFrame:SetHeight(playerVisible * PLAYER_H)

	-- names the game did not have yet: look again in a moment (a few times)
	local missing = false
	for _, g in ipairs(groups) do
		if not select(4, itemInfo(g.itemID)) then missing = true end
	end
	if missing and retries < 8 and C_Timer then
		retries = retries + 1
		C_Timer.After(1.5, function() SessionWindow:Refresh() end)
	end

	-- the buttons for a session that runs in ALC
	local live = C.live ~= nil
	local Sessions = ALC and ALC.Sessions
	-- every item awarded: the session only waits for the undo time to run out
	local finishing = live and session.state == "accepted" and Sessions and Sessions.GetFinishLeft and Sessions:GetFinishLeft() ~= nil
	buttons.pause:SetShown(live and not finishing)
	buttons.stop:SetShown(live)
	buttons.stop:SetLabel(finishing and "Close session" or "Stop session")
	if live then
		local paused = ALC.Sessions and ALC.Sessions.IsPaused and ALC.Sessions:IsPaused()
		buttons.pause:SetLabel(paused and "Resume" or "Pause")
		if paused then stateTag:SetText("PAUSED") end
	end

	local can = C:Can()
	buttons.resolve:SetAvailable(can.resolve)
	buttons.reroll:SetAvailable(can.reroll)
	if live and session.state == "accepted" then
		-- accepted but the winners are not all awarded yet (the question was closed, say): ask again from here
		local open = Sessions and Sessions.GetSummary and Sessions:GetSummary().open or 0
		buttons.accept:SetLabel("Award all")
		buttons.accept:SetAvailable(open > 0 and not finishing)
	else
		buttons.accept:SetLabel("Accept result")
		buttons.accept:SetAvailable(can.accept)
	end
	buttons.reopen:SetAvailable(can.reopen)
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

-- For a session in ALC: the rolls go to the council's list and the result to everybody's Result window.
local function shareResult(state)
	if Controller().live and ASR.SoftRes.Bridge then
		ASR.SoftRes.Bridge.PushRolls()
		ASR.SoftRes.Bridge.PublishResults(state)
	end
end

local function resolve()
	local waiting = Controller().session:Resolve()
	Controller():Save() -- the rolls must survive a /reload at once
	shareResult("resolved")
	if waiting and waiting > 0 then
		ASR:Print(waiting .. (waiting == 1 and " item is" or " items are") .. " tied. Press Reroll ties.")
	end
	SessionWindow:Refresh()
end

SessionWindow.DoResolve = resolve -- for the auto-Resolve when the answer time is up (see Bridge)

local function reroll()
	local session = Controller().session
	for _, group in ipairs(session.groups) do
		if group.result and #group.result.ties > 0 then session:Reroll(group.slots[1]) end
	end
	Controller():Save() -- the rolls must survive a /reload at once
	shareResult("resolved")
	SessionWindow:Refresh()
end

local function accept()
	if Controller().session.state == "accepted" then
		-- already accepted: this button is "Award all" now
		local shown, why = ASR.SoftRes.Bridge.RequestAwards()
		if not shown and why then ASR:Print(why) end
		return
	end
	local lines, message = Controller():Accept(itemNameForChat)
	if not lines then
		ASR:Print(message or "Could not accept.")
		return
	end
	if Controller().live then
		shareResult("accepted")
		ASR:Print("Result accepted:")
	else
		ASR:Print("Result accepted (a test: nothing is handed out):")
	end
	for _, line in ipairs(lines) do ASR:Print("  " .. line) end
	if Controller().live then
		ASR.SoftRes.Bridge.AnnounceResult(itemNameForChat) -- in the raid chat, if the loot master asked for that
		local shown, why = ASR.SoftRes.Bridge.RequestAwards()
		if not shown and why then ASR:Print(why) end
	end
	SessionWindow:Refresh()
end

local function pauseSession()
	local ok, message = ALC.Sessions:SetPaused(not ALC.Sessions:IsPaused())
	if not ok and message then ASR:Print(message) end
	SessionWindow:Refresh()
end

local function stopSession()
	local ok, message = ALC.Sessions:Cancel("stopped")
	if not ok and message then ASR:Print(message) end
end

local function reopen()
	Controller().session:Reopen()
	Controller():Save() -- the rolls must survive a /reload at once
	shareResult("resolved")
	SessionWindow:Refresh()
end

-- Reopen throws the rolls away, so it asks first.
local confirmFrame
local function askReopen()
	if not confirmFrame then
		local f = CreateFrame("Frame", nil, UIParent)
		f:SetSize(400, 170)
		f:SetFrameStrata("FULLSCREEN_DIALOG")
		f:SetFrameLevel(10)
		f:EnableMouse(true)
		f:Hide()
		local bg = UI.NewFill(f, 10)
		UI.SetTextureColor(bg, c.bg)
		UI.AddBorder(f, c.gold, 1, 10)
		local title = UI.NewText(f, 14, c.text)
		title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAD)
		title:SetText("REOPEN ANSWERS?")
		local text = UI.NewText(f, 13, c.muted)
		text:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(PAD + 30))
		text:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
		text:SetWordWrap(true)
		text:SetJustifyV("TOP")
		text:SetText("Reopening will reset all rolls, ties and the result. The answers stay. Press Resolve again to roll again: everybody gets new rolls.")
		local yes = UI.NewButton(f, 130, 34, "Reopen", function() f:Hide() reopen() end)
		yes:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
		local no = UI.NewButton(f, 110, 34, "Cancel", function() f:Hide() end)
		no:SetPoint("RIGHT", yes, "LEFT", -8, 0)
		confirmFrame = f
	end
	confirmFrame:ClearAllPoints()
	confirmFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
	confirmFrame:Show()
end

-- ---------------------------------------------------------------------------
-- Frame
-- ---------------------------------------------------------------------------

local function savePosition()
	if not ASR.db then return end
	local point, _, relPoint, x, y = frame:GetPoint()
	ASR.db.windows = ASR.db.windows or {}
	ASR.db.windows.session = { point = point, relPoint = relPoint, x = x, y = y }
end

local function restorePosition()
	frame:ClearAllPoints()
	local pos = ASR.db and ASR.db.windows and ASR.db.windows.session
	if pos and pos.point then
		frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	end
end

local function build()
	frame = CreateFrame("Frame", "ArbiterSoftReserveSession", UIParent)
	UI.RegisterScaled(frame)
	frame:SetSize(WIDTH, 300)
	frame:SetFrameStrata("HIGH")
	frame:SetFrameLevel(30)
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:Hide()
	if UISpecialFrames then table.insert(UISpecialFrames, "ArbiterSoftReserveSession") end

	local bg = UI.NewFill(frame, 10)
	UI.SetTextureColor(bg, c.bg)
	UI.AddBorder(frame, c.border, 1, 10)

	local bar = CreateFrame("Frame", nil, frame)
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	bar:SetHeight(HEADER_H)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function() frame:StartMoving() end)
	bar:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		savePosition()
	end)

	local logo = bar:CreateTexture(nil, "ARTWORK")
	logo:SetSize(22, 22)
	logo:SetPoint("LEFT", bar, "LEFT", PAD, 0)
	logo:SetTexture(MEDIA .. "Logo\\asr_mark_64")
	local title = UI.NewText(bar, 15, c.text)
	title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
	title:SetText("SOFT RESERVE")

	local close = CreateFrame("Button", nil, bar)
	close:SetSize(30, 30)
	close:SetPoint("RIGHT", bar, "RIGHT", -12, 0)
	close.text = UI.NewText(close, 30, c.muted, "CENTER")
	close.text:SetPoint("CENTER", 0, 0)
	close.text:SetText("\195\151")
	close:SetScript("OnEnter", function(self) self.text:SetTextColor(c.text[1], c.text[2], c.text[3], 1) end)
	close:SetScript("OnLeave", function(self) self.text:SetTextColor(c.muted[1], c.muted[2], c.muted[3], 1) end)
	close:SetScript("OnClick", function() SessionWindow:Hide() end)

	stateTag = UI.NewText(bar, 12, c.gold, "RIGHT")
	stateTag:SetPoint("RIGHT", close, "LEFT", -14, 0)
	timerText = UI.NewText(bar, 13, c.gold, "RIGHT")
	timerText:SetPoint("RIGHT", stateTag, "LEFT", -18, 0)
	-- the countdown ticks a few times a second while the window is open
	local sinceTick, sinceTrades = 0, 0
	frame:SetScript("OnUpdate", function(_, elapsed)
		sinceTick = sinceTick + elapsed
		if sinceTick < 0.25 then return end
		sinceTick = 0
		SessionWindow:UpdateTimer()
		if view == "trades" then
			sinceTrades = sinceTrades + 0.25
			if sinceTrades >= 15 then sinceTrades = 0 SessionWindow:Refresh() end
		end
	end)

	local divider = frame:CreateTexture(nil, "BORDER")
	divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -HEADER_H)
	divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -HEADER_H)
	divider:SetHeight(1)
	UI.SetTextureColor(divider, c.border)

	banner = UI.NewText(frame, 12, c.muted)
	banner:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(HEADER_H + 12))
	banner:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)

	-- the items
	local top = TOP_H
	local list = CreateFrame("Frame", nil, frame)
	itemList = list
	list:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -top)
	list:SetSize(LIST_W, ITEM_ROWS * (ITEM_H + ITEM_GAP))
	for i = 1, ITEM_ROWS do itemRows[i] = buildItemRow(list, i) end
	itemBar = UI.NewScrollBar(list, function(offset)
		itemOffset = offset
		SessionWindow:Refresh()
	end)
	itemBar:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, 0)
	itemBar:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, delta)
		itemOffset = itemOffset - delta
		SessionWindow:Refresh()
	end)

	-- the players of the selected item
	local right = CreateFrame("Frame", nil, frame)
	rightPane = right
	right:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + LIST_W + 20, -top)
	right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, FOOTER_H)
	header = UI.NewText(right, 16, c.text)
	header:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
	header:SetPoint("RIGHT", right, "RIGHT", 0, 0)
	headerSub = UI.NewText(right, 12, c.muted)
	headerSub:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -24)
	headerSub:SetPoint("RIGHT", right, "RIGHT", 0, 0)

	local heads = { { "Player", COL.name }, { "Answer", COL.answer }, { "Roll", COL.roll }, { "Result", COL.result } }
	for _, h in ipairs(heads) do
		local fs = UI.NewText(right, 11, c.muted)
		fs:SetPoint("TOPLEFT", right, "TOPLEFT", h[2], -52)
		fs:SetText(string.upper(h[1]))
	end
	local rowsFrame = CreateFrame("Frame", nil, right)
	rowsFrame:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -72)
	rowsFrame:SetPoint("RIGHT", right, "RIGHT", 0, 0)
	rowsFrame:SetHeight(PLAYER_H * MIN_PLAYER_ROWS)
	playerRowsFrame = rowsFrame
	for i = 1, PLAYER_ROWS do playerRows[i] = buildPlayerRow(rowsFrame, i) end
	playerBar = UI.NewScrollBar(rowsFrame, function(offset)
		playerOffset = offset
		SessionWindow:Refresh()
	end)
	playerBar:SetPoint("TOPRIGHT", rowsFrame, "TOPRIGHT", 0, 0)
	playerBar:SetPoint("BOTTOMRIGHT", rowsFrame, "BOTTOMRIGHT", 0, 0)
	rowsFrame:EnableMouseWheel(true)
	rowsFrame:SetScript("OnMouseWheel", function(_, delta)
		playerOffset = playerOffset - delta * 3
		SessionWindow:Refresh()
	end)

	-- the trade queue (its own view)
	tradeFrame = CreateFrame("Frame", nil, frame)
	tradeFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -top)
	tradeFrame:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
	tradeFrame:SetHeight(TRADE_ROWS * (TRADE_H + TRADE_GAP))
	for i = 1, TRADE_ROWS do tradeRows[i] = buildTradeRow(tradeFrame, i) end
	tradeBar = UI.NewScrollBar(tradeFrame, function(offset)
		tradeOffset = offset
		SessionWindow:Refresh()
	end)
	tradeBar:SetPoint("TOPRIGHT", tradeFrame, "TOPRIGHT", 0, 0)
	tradeBar:SetPoint("BOTTOMRIGHT", tradeFrame, "BOTTOMRIGHT", 0, 0)
	tradeFrame:EnableMouseWheel(true)
	tradeFrame:SetScript("OnMouseWheel", function(_, delta)
		tradeOffset = tradeOffset - delta
		SessionWindow:Refresh()
	end)
	tradeEmpty = UI.NewText(frame, 13, c.muted)
	tradeEmpty:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(top + 8))
	tradeEmpty:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
	tradeEmpty:SetWordWrap(true)
	tradeEmpty:SetText("Nothing is waiting to be traded. Items you award that are not in the loot window of the corpse show up here, with a Trade button that opens the trade with the winner.")
	tradeEmpty:Hide()

	-- the two views, in the header
	tabButtons.session = UI.NewButton(bar, 80, 26, "Session", function() SessionWindow:SetView("session") end)
	tabButtons.session:SetPoint("LEFT", title, "RIGHT", 28, 0)
	tabButtons.trades = UI.NewButton(bar, 130, 26, "Trade queue", function() SessionWindow:SetView("trades") end)
	tabButtons.trades:SetPoint("LEFT", tabButtons.session, "RIGHT", 6, 0)
	if ALC and ALC.Events and ALC.Events.Register then
		ALC.Events.Register(SessionWindow, "ALC_LOOT_CHANGED", function() SessionWindow:Refresh() end)
	end

	-- the buttons
	local footer = frame:CreateTexture(nil, "BORDER")
	footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, FOOTER_H - 14)
	footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, FOOTER_H - 14)
	footer:SetHeight(1)
	UI.SetTextureColor(footer, c.border)
	buttons.resolve = UI.NewButton(frame, 88, 32, "Resolve", resolve)
	buttons.resolve:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 12)
	buttons.reroll = UI.NewButton(frame, 98, 32, "Reroll ties", reroll)
	buttons.reroll:SetPoint("LEFT", buttons.resolve, "RIGHT", 8, 0)
	buttons.accept = UI.NewButton(frame, 112, 32, "Accept result", accept)
	buttons.accept:SetPoint("LEFT", buttons.reroll, "RIGHT", 8, 0)
	buttons.reopen = UI.NewButton(frame, 124, 32, "Reopen answers", askReopen)
	buttons.reopen:SetPoint("LEFT", buttons.accept, "RIGHT", 8, 0)
	-- only for a session that runs in Arbiter Loot Council (the loot master's own controls live in ASR's window,
	-- so the council window is not needed for a soft reserve session)
	buttons.pause = UI.NewButton(frame, 76, 32, "Pause", pauseSession)
	buttons.pause:SetPoint("LEFT", buttons.reopen, "RIGHT", 12, 0)
	buttons.stop = UI.NewButton(frame, 104, 32, "Stop session", stopSession)
	buttons.stop:SetPoint("LEFT", buttons.pause, "RIGHT", 8, 0)
	local closeButton = UI.NewButton(frame, 76, 32, "Close", function() SessionWindow:Hide() end)
	closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 12)

	-- item names arrive a moment after the first look: paint again
	frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	frame:SetScript("OnEvent", function() SessionWindow:Refresh() end)
	restorePosition()
end

-- Opens the window on the running session. Returns false when there is none.
function SessionWindow:Show()
	if not Controller().session then return false end
	UI = ALC and ALC.UI
	if not UI then
		ASR:Print("The window needs Arbiter Loot Council (its look and widgets), which did not load.")
		return true
	end
	c = UI.color
	if not frame then build() end
	selected, itemOffset, playerOffset = 1, 0, 0
	retries = 0
	view = "session"
	frame:Show()
	self:Refresh()
	return true
end

-- Switches between the session and the trade queue.
function SessionWindow:SetView(newView)
	view = newView == "trades" and "trades" or "session"
	if view == "session" and not Controller().session then view = "trades" end
	self:Refresh()
end

-- Opens the window on the trade queue (also when there is no session).
function SessionWindow:ShowTrades()
	UI = ALC and ALC.UI
	if not UI then
		ASR:Print("The window needs Arbiter Loot Council (its look and widgets), which did not load.")
		return false
	end
	c = UI.color
	if not frame then build() end
	view, tradeOffset = "trades", 0
	frame:Show()
	self:Refresh()
	return true
end

function SessionWindow:Hide()
	if confirmFrame then confirmFrame:Hide() end
	if frame then frame:Hide() end
end
