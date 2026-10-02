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

local WIDTH, HEIGHT, PAD = 860, 600, 16
local HEADER_H = 52
local LIST_W, ITEM_H, ITEM_ROWS, ITEM_GAP = 280, 56, 8, 4
local PLAYER_H, PLAYER_ROWS = 28, 15
local COL = { name = 12, answer = 196, roll = 262, result = 390 }
local PURPLE = { 0.61, 0.48, 1, 1 }
local MEDIA = "Interface\\AddOns\\ArbiterSoftReserve\\Media\\"

local frame, UI, c
local stateTag, banner, header, headerSub
local itemRows, playerRows = {}, {}
local buttons = {}
local itemBar, playerBar
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
	row.icon:SetSize(38, 38)
	row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
	row.name = UI.NewText(row, 13, c.text)
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -2)
	row.name:SetPoint("RIGHT", row, "RIGHT", -40, 0)
	row.status = UI.NewText(row, 12, c.muted)
	row.status:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 2)
	row.status:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	row.copies = UI.NewText(row, 13, PURPLE, "RIGHT")
	row.copies:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -8)
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
	local sc = info.tied and c.gold or c.muted
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
	row.answer:SetText(ANSWER[data.answer] or "")
	row.roll:SetText(Controller().RollText(data))
	row.result:SetText(Controller().OutcomeText(data))
	local rc = c.muted
	if data.outcome == "won" then rc = GREEN elseif data.outcome == "tied" then rc = c.gold end
	row.result:SetTextColor(rc[1], rc[2], rc[3], 1)
end

-- ---------------------------------------------------------------------------
-- Refresh
-- ---------------------------------------------------------------------------

local STATE_TEXT = { open = "WAITING FOR ANSWERS", resolved = "RESOLVED", accepted = "ACCEPTED" }

function SessionWindow:Refresh()
	if not frame or not frame:IsShown() then return end
	local C = Controller()
	local session = C.session
	if not session then return end
	stateTag:SetText(STATE_TEXT[session.state] or "")
	banner:SetText(C.live and "A soft reserve session in Arbiter Loot Council. Answers come in as the players give them; the rolls are made when you press Resolve."
		or "A test: the players next to the real reservers are made up, and nothing is handed out.")

	local groups = session.groups
	selected = math.max(1, math.min(selected, #groups))
	itemOffset = math.max(0, math.min(itemOffset, math.max(0, #groups - ITEM_ROWS)))
	for i, row in ipairs(itemRows) do
		local group = groups[i + itemOffset]
		if group then
			row:Show()
			paintItemRow(row, group, i + itemOffset)
		else
			row:Hide()
		end
	end
	itemBar:Update(#groups, ITEM_ROWS, itemOffset)

	local group = groups[selected]
	header:SetText((itemInfo(group.itemID)))
	local info = C:GroupInfo(group)
	headerSub:SetText((group.copies > 1 and (group.copies .. " copies. ") or "1 copy. ") .. info.status)
	local rows = C:Rows(group)
	playerOffset = math.max(0, math.min(playerOffset, math.max(0, #rows - PLAYER_ROWS)))
	for i, row in ipairs(playerRows) do paintPlayerRow(row, rows[i + playerOffset]) end
	playerBar:Update(#rows, PLAYER_ROWS, playerOffset)

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
	buttons.pause:SetShown(live)
	buttons.stop:SetShown(live)
	if live then
		local paused = ALC.Sessions and ALC.Sessions.IsPaused and ALC.Sessions:IsPaused()
		buttons.pause:SetLabel(paused and "Resume" or "Pause")
		if paused then stateTag:SetText("PAUSED") end
	end

	local can = C:Can()
	buttons.resolve:SetAvailable(can.resolve)
	buttons.reroll:SetAvailable(can.reroll)
	buttons.accept:SetAvailable(can.accept)
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
	shareResult("resolved")
	if waiting and waiting > 0 then
		ASR:Print(waiting .. (waiting == 1 and " item is" or " items are") .. " tied. Press Reroll ties.")
	end
	SessionWindow:Refresh()
end

local function reroll()
	local session = Controller().session
	for _, group in ipairs(session.groups) do
		if group.result and #group.result.ties > 0 then session:Reroll(group.slots[1]) end
	end
	shareResult("resolved")
	SessionWindow:Refresh()
end

local function accept()
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
	shareResult("resolved")
	SessionWindow:Refresh()
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
	frame:SetSize(WIDTH, HEIGHT)
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
	logo:SetSize(28, 28)
	logo:SetPoint("LEFT", bar, "LEFT", PAD, 0)
	logo:SetTexture(MEDIA .. "Logo\\asr_mark_64")
	local title = UI.NewText(bar, 15, c.text)
	title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
	title:SetText("SOFT RESERVE")

	local close = CreateFrame("Button", nil, bar)
	close:SetSize(28, 28)
	close:SetPoint("RIGHT", bar, "RIGHT", -12, 0)
	close.text = UI.NewText(close, 22, c.muted, "CENTER")
	close.text:SetPoint("CENTER", 0, 0)
	close.text:SetText("\195\151")
	close:SetScript("OnEnter", function(self) self.text:SetTextColor(c.text[1], c.text[2], c.text[3], 1) end)
	close:SetScript("OnLeave", function(self) self.text:SetTextColor(c.muted[1], c.muted[2], c.muted[3], 1) end)
	close:SetScript("OnClick", function() SessionWindow:Hide() end)

	stateTag = UI.NewText(bar, 12, c.gold, "RIGHT")
	stateTag:SetPoint("RIGHT", close, "LEFT", -14, 0)

	local divider = frame:CreateTexture(nil, "BORDER")
	divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -HEADER_H)
	divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -HEADER_H)
	divider:SetHeight(1)
	UI.SetTextureColor(divider, c.border)

	banner = UI.NewText(frame, 12, c.muted)
	banner:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(HEADER_H + 12))
	banner:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)

	-- the items
	local top = HEADER_H + 40
	local list = CreateFrame("Frame", nil, frame)
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
	right:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + LIST_W + 20, -top)
	right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 70)
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
	rowsFrame:SetHeight(PLAYER_H * PLAYER_ROWS)
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

	-- the buttons
	local footer = frame:CreateTexture(nil, "BORDER")
	footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 56)
	footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 56)
	footer:SetHeight(1)
	UI.SetTextureColor(footer, c.border)
	buttons.resolve = UI.NewButton(frame, 100, 32, "Resolve", resolve)
	buttons.resolve:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 12)
	buttons.reroll = UI.NewButton(frame, 110, 32, "Reroll ties", reroll)
	buttons.reroll:SetPoint("LEFT", buttons.resolve, "RIGHT", 8, 0)
	buttons.accept = UI.NewButton(frame, 130, 32, "Accept result", accept)
	buttons.accept:SetPoint("LEFT", buttons.reroll, "RIGHT", 8, 0)
	buttons.reopen = UI.NewButton(frame, 140, 32, "Reopen answers", reopen)
	buttons.reopen:SetPoint("LEFT", buttons.accept, "RIGHT", 8, 0)
	-- only for a session that runs in Arbiter Loot Council (the loot master's own controls live in ASR's window,
	-- so the council window is not needed for a soft reserve session)
	buttons.pause = UI.NewButton(frame, 90, 32, "Pause", pauseSession)
	buttons.pause:SetPoint("LEFT", buttons.reopen, "RIGHT", 16, 0)
	buttons.stop = UI.NewButton(frame, 120, 32, "Stop session", stopSession)
	buttons.stop:SetPoint("LEFT", buttons.pause, "RIGHT", 8, 0)
	local closeButton = UI.NewButton(frame, 90, 32, "Close", function() SessionWindow:Hide() end)
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
	frame:Show()
	self:Refresh()
	return true
end

function SessionWindow:Hide()
	if frame then frame:Hide() end
end
