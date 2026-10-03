-- ResultsWindow: /asr results. What the soft reserve sessions decided, kept between sessions (SoftRes/History): pick a
-- session, then look at it by item (who got it, what everybody rolled) or by player (what one player rolled for and
-- won). Read only. Built from Arbiter Loot Council's widgets like the session window, with ASR's purple mark.
local _, ASR = ...

local ResultsWindow = {}
ASR.ResultsWindow = ResultsWindow

local History = function() return ASR.SoftRes.History end
local Controller = function() return ASR.SoftRes.Controller end

local WIDTH, PAD = 780, 16
local HEADER_H, TOOLBAR_H = 40, 48
local LIST_W, ROW_H, LIST_ROWS, LIST_GAP = 240, 46, 8, 4
local LINE_H, LINE_ROWS, MIN_LINES = 24, 12, 3
local TOP_H = HEADER_H + TOOLBAR_H
local HEAD_H = 72 -- the title and sub line of the right side and the column heads
local FOOTER_H = 62
local COL = { name = 12, answer = 190, roll = 250, result = 360 }
local PURPLE = { 0.61, 0.48, 1, 1 }
local GREEN = { 0.30, 0.75, 0.40, 1 }
local MEDIA = "Interface\\AddOns\\ArbiterSoftReserve\\Media\\"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local frame, UI, c
local sessionText, byItemButton, byPlayerButton, prevButton, nextButton, emptyText
local title, sub, firstHead
local listRows, lineRows = {}, {}
local listBar, lineBar, listFrame, linesFrame
local sessionIndex, mode = 1, "item" -- which session (1 = the newest), "item" or "player"
local selected, listOffset, lineOffset = 1, 0, 0
local listVisible, lineVisible = 1, MIN_LINES

local ANSWER = { MS = "MS", OS = "OS", PASS = "Pass", SR = "SR" }

-- ---------------------------------------------------------------------------
-- Little helpers
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
	return name or ("item " .. itemID), quality or 1, icon
end

local function when(t)
	local fmt = date or os.date
	return fmt("%Y-%m-%d %H:%M", t or 0)
end

local function rollText(row)
	if row.silent or row.roll == nil then return "-" end
	return Controller().RollText(row)
end

local VIA = { SR = "SR", MS = "MS", OS = "OS" }

local function outcomeText(row)
	if row.silent then return "Did not answer, no roll" end
	if row.disenchant then return "Disenchanted" end
	if row.outcome == "won" then return "Won (" .. (VIA[row.via] or tostring(row.via)) .. ")" end
	if row.outcome == "tied" then return "Tied" end
	if row.outcome == "passed" then return "Passed" end
	return row.roll and "Lost" or ""
end

local function outcomeColor(row)
	if row.silent then return c.danger end
	if row.disenchant then return PURPLE end
	if row.outcome == "won" then return GREEN end
	if row.outcome == "tied" then return c.gold end
	return c.muted
end

-- What the window shows now: the chosen session, the list on the left and the lines on the right.
local function model()
	local list = History().Sessions()
	sessionIndex = math.max(1, math.min(sessionIndex, math.max(1, #list)))
	local session = list[sessionIndex]
	if not session then return list, nil, {}, {} end
	if mode == "player" then
		local players = History().ByPlayer(session)
		selected = math.max(1, math.min(selected, math.max(1, #players)))
		return list, session, players, players[selected] and players[selected].entries or {}
	end
	local items = History().ByItem(session)
	selected = math.max(1, math.min(selected, math.max(1, #items)))
	return list, session, items, items[selected] and items[selected].rows or {}
end

-- ---------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------

local function buildListRow(parent, index)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(ROW_H)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * (ROW_H + LIST_GAP))
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -(index - 1) * (ROW_H + LIST_GAP))
	row:RegisterForClicks("LeftButtonUp")
	row.bg = UI.NewFill(row, 6)
	row.border = UI.AddBorder(row, c.border, 1, 6)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(32, 32)
	row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
	row.name = UI.NewText(row, 13, c.text)
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -1)
	row.name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	row.status = UI.NewText(row, 11, c.muted)
	row.status:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 1)
	row.status:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	function row:look(hover)
		if self.index == selected then
			UI.SetTextureColor(self.bg, c.goldTint)
			self.border:SetColor(c.gold)
		else
			UI.SetTextureColor(self.bg, hover and c.panelHover or c.panel)
			self.border:SetColor(hover and c.gold or c.border)
		end
	end
	row:SetScript("OnEnter", function(self)
		self:look(true)
		if mode == "item" and GameTooltip and self.itemID then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink("item:" .. self.itemID)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function(self)
		self:look(false)
		if GameTooltip then GameTooltip:Hide() end
	end)
	row:SetScript("OnClick", function(self)
		selected = self.index
		lineOffset = 0
		ResultsWindow:Refresh()
	end)
	return row
end

local function paintListRow(row, entry, index)
	row.index = index
	row.itemID = nil
	if mode == "item" then
		row.itemID = entry.itemID
		local name, quality, icon = itemInfo(entry.itemID)
		local q = UI.QualityColor(quality)
		row.name:SetTextColor(q[1], q[2], q[3], 1)
		row.name:SetText(name)
		row.icon:SetTexture(icon or UNKNOWN_ICON)
		local text
		if entry.tied then text = "Tie, not decided"
		elseif #entry.winners > 0 then text = "Winner: " .. table.concat(entry.winners, ", ")
		elseif #entry.disenchanted > 0 then text = "Disenchanted by " .. table.concat(entry.disenchanted, ", ")
		else text = "Nobody won it" end
		if entry.state ~= "accepted" and not entry.tied then text = text .. " (not accepted)" end
		row.status:SetText(text)
		local sc = (entry.tied or entry.state ~= "accepted") and c.gold or c.muted
		row.status:SetTextColor(sc[1], sc[2], sc[3], 1)
	else
		row.name:SetTextColor(c.text[1], c.text[2], c.text[3], 1)
		row.name:SetText(entry.name)
		local first
		for _, e in ipairs(entry.entries) do
			if e.outcome == "won" then first = e break end
		end
		if first then
			row.icon:SetTexture(select(3, itemInfo(first.itemID)) or UNKNOWN_ICON)
		else
			row.icon:SetTexture(UNKNOWN_ICON)
		end
		row.status:SetText(entry.wins == 0 and "Won nothing" or ("Won " .. entry.wins .. (entry.wins == 1 and " item" or " items")))
		local sc = entry.wins > 0 and GREEN or c.muted
		row.status:SetTextColor(sc[1], sc[2], sc[3], 1)
	end
	row:look(false)
end

local function buildLine(parent, index)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(LINE_H)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * LINE_H)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -(index - 1) * LINE_H)
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

local function paintLine(row, data)
	if not data then row:Hide() return end
	row:Show()
	row.tag:SetText(data.reserved and "SR" or "")
	if mode == "player" then
		-- one line per item the player took part in: the item's name in its quality colour
		local name, quality = itemInfo(data.itemID)
		local q = UI.QualityColor(quality)
		row.name:SetTextColor(q[1], q[2], q[3], 1)
		row.name:SetText(name)
	else
		row.name:SetTextColor(c.text[1], c.text[2], c.text[3], 1)
		row.name:SetText(data.name)
	end
	row.answer:SetText(data.silent and "None" or (ANSWER[data.answer] or tostring(data.answer or "")))
	row.roll:SetText(rollText(data))
	row.result:SetText(outcomeText(data))
	local rc = outcomeColor(data)
	row.result:SetTextColor(rc[1], rc[2], rc[3], 1)
end

-- ---------------------------------------------------------------------------
-- Refresh
-- ---------------------------------------------------------------------------

function ResultsWindow:Refresh()
	if not frame or not frame:IsShown() then return end
	local sessions, session, entries, lines = model()
	byItemButton:SetSelected(mode == "item")
	byPlayerButton:SetSelected(mode == "player")
	prevButton:SetAvailable(sessionIndex < #sessions)
	nextButton:SetAvailable(sessionIndex > 1)
	emptyText:SetShown(session == nil)

	if not session then
		sessionText:SetText("No results yet")
		title:SetText("")
		sub:SetText("")
		for _, row in ipairs(listRows) do row:Hide() end
		for _, row in ipairs(lineRows) do row:Hide() end
		listBar:Update(0, 1, 0)
		lineBar:Update(0, 1, 0)
		frame:SetHeight(TOP_H + 120 + FOOTER_H)
		return
	end

	local count = 0
	for _ in pairs(session.items) do count = count + 1 end
	sessionText:SetText(string.format("%s  \194\183  %d of %d  \194\183  %d %s", when(session.time), sessionIndex, #sessions, count, count == 1 and "item" or "items"))
	firstHead:SetText(mode == "player" and "ITEM" or "PLAYER")

	listVisible = math.max(1, math.min(#entries, LIST_ROWS))
	listOffset = math.max(0, math.min(listOffset, math.max(0, #entries - listVisible)))
	for i, row in ipairs(listRows) do
		local entry = entries[i + listOffset]
		if entry and i <= listVisible then
			row:Show()
			paintListRow(row, entry, i + listOffset)
		else
			row:Hide()
		end
	end
	listBar:Update(#entries, listVisible, listOffset)

	local current = entries[selected]
	if current then
		if mode == "player" then
			title:SetText(current.name)
			sub:SetText(string.format("Rolled for %d, won %d", current.rolled, current.wins))
		else
			title:SetText((itemInfo(current.itemID)))
			local text = string.format("%d rolled", current.rolled)
			if current.silent > 0 then text = text .. string.format(", %d reserved it and did not answer", current.silent) end
			if current.state ~= "accepted" then text = text .. " (the result was not accepted)" end
			sub:SetText(text)
		end
	end

	lineVisible = math.max(MIN_LINES, math.min(#lines, LINE_ROWS))
	lineOffset = math.max(0, math.min(lineOffset, math.max(0, #lines - lineVisible)))
	for i, row in ipairs(lineRows) do paintLine(row, i <= lineVisible and lines[i + lineOffset] or nil) end
	lineBar:Update(#lines, lineVisible, lineOffset)

	local listHeight = listVisible * (ROW_H + LIST_GAP)
	local linesHeight = HEAD_H + lineVisible * LINE_H
	frame:SetHeight(TOP_H + math.max(listHeight, linesHeight) + FOOTER_H)
	listFrame:SetHeight(listHeight)
	linesFrame:SetHeight(lineVisible * LINE_H)
end

-- ---------------------------------------------------------------------------
-- Frame
-- ---------------------------------------------------------------------------

local function savePosition()
	if not ASR.db then return end
	local point, _, relPoint, x, y = frame:GetPoint()
	ASR.db.windows = ASR.db.windows or {}
	ASR.db.windows.results = { point = point, relPoint = relPoint, x = x, y = y }
end

local function restorePosition()
	frame:ClearAllPoints()
	local pos = ASR.db and ASR.db.windows and ASR.db.windows.results
	if pos and pos.point then
		frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	end
end

local function setMode(newMode)
	if mode == newMode then return end
	mode, selected, listOffset, lineOffset = newMode, 1, 0, 0
	ResultsWindow:Refresh()
end

local function build()
	frame = CreateFrame("Frame", "ArbiterSoftReserveResults", UIParent)
	UI.RegisterScaled(frame)
	frame:SetSize(WIDTH, 300)
	frame:SetFrameStrata("HIGH")
	frame:SetFrameLevel(30)
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:Hide()
	if UISpecialFrames then table.insert(UISpecialFrames, "ArbiterSoftReserveResults") end

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
	local head = UI.NewText(bar, 15, c.text)
	head:SetPoint("LEFT", logo, "RIGHT", 10, 0)
	head:SetText("SOFT RESERVE RESULTS")

	local close = CreateFrame("Button", nil, bar)
	close:SetSize(24, 24)
	close:SetPoint("RIGHT", bar, "RIGHT", -12, 0)
	close.text = UI.NewText(close, 22, c.muted, "CENTER")
	close.text:SetPoint("CENTER", 0, 0)
	close.text:SetText("\195\151")
	close:SetScript("OnEnter", function(self) self.text:SetTextColor(c.text[1], c.text[2], c.text[3], 1) end)
	close:SetScript("OnLeave", function(self) self.text:SetTextColor(c.muted[1], c.muted[2], c.muted[3], 1) end)
	close:SetScript("OnClick", function() ResultsWindow:Hide() end)

	local divider = frame:CreateTexture(nil, "BORDER")
	divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -HEADER_H)
	divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -HEADER_H)
	divider:SetHeight(1)
	UI.SetTextureColor(divider, c.border)

	-- the toolbar: which session, and by item or by player
	prevButton = UI.NewButton(frame, 30, 28, "<", function() sessionIndex = sessionIndex + 1 selected, listOffset, lineOffset = 1, 0, 0 ResultsWindow:Refresh() end)
	prevButton:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(HEADER_H + 12))
	nextButton = UI.NewButton(frame, 30, 28, ">", function() sessionIndex = sessionIndex - 1 selected, listOffset, lineOffset = 1, 0, 0 ResultsWindow:Refresh() end)
	nextButton:SetPoint("LEFT", prevButton, "RIGHT", 6, 0)
	sessionText = UI.NewText(frame, 13, c.text)
	sessionText:SetPoint("LEFT", nextButton, "RIGHT", 12, 0)
	byPlayerButton = UI.NewButton(frame, 96, 28, "By player", function() setMode("player") end)
	byPlayerButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(HEADER_H + 12))
	byItemButton = UI.NewButton(frame, 90, 28, "By item", function() setMode("item") end)
	byItemButton:SetPoint("RIGHT", byPlayerButton, "LEFT", -6, 0)

	emptyText = UI.NewText(frame, 13, c.muted)
	emptyText:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(TOP_H + 16))
	emptyText:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
	emptyText:SetWordWrap(true)
	emptyText:SetText("Nothing has been decided yet. When a soft reserve session is resolved, every item and every roll is kept here, for the last 15 sessions.")

	-- the list on the left
	listFrame = CreateFrame("Frame", nil, frame)
	listFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TOP_H)
	listFrame:SetSize(LIST_W, LIST_ROWS * (ROW_H + LIST_GAP))
	for i = 1, LIST_ROWS do listRows[i] = buildListRow(listFrame, i) end
	listBar = UI.NewScrollBar(listFrame, function(offset)
		listOffset = offset
		ResultsWindow:Refresh()
	end)
	listBar:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", 0, 0)
	listBar:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", 0, 0)
	listFrame:EnableMouseWheel(true)
	listFrame:SetScript("OnMouseWheel", function(_, delta)
		listOffset = listOffset - delta
		ResultsWindow:Refresh()
	end)

	-- the lines on the right
	local right = CreateFrame("Frame", nil, frame)
	right:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + LIST_W + 20, -TOP_H)
	right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, FOOTER_H)
	title = UI.NewText(right, 16, c.text)
	title:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
	title:SetPoint("RIGHT", right, "RIGHT", 0, 0)
	sub = UI.NewText(right, 12, c.muted)
	sub:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -24)
	sub:SetPoint("RIGHT", right, "RIGHT", 0, 0)
	local heads = { { "", COL.name }, { "Answer", COL.answer }, { "Roll", COL.roll }, { "Result", COL.result } }
	for i, h in ipairs(heads) do
		local fs = UI.NewText(right, 11, c.muted)
		fs:SetPoint("TOPLEFT", right, "TOPLEFT", h[2], -52)
		fs:SetText(string.upper(h[1]))
		if i == 1 then firstHead = fs end
	end
	linesFrame = CreateFrame("Frame", nil, right)
	linesFrame:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -HEAD_H)
	linesFrame:SetPoint("RIGHT", right, "RIGHT", 0, 0)
	linesFrame:SetHeight(LINE_H * MIN_LINES)
	for i = 1, LINE_ROWS do lineRows[i] = buildLine(linesFrame, i) end
	lineBar = UI.NewScrollBar(linesFrame, function(offset)
		lineOffset = offset
		ResultsWindow:Refresh()
	end)
	lineBar:SetPoint("TOPRIGHT", linesFrame, "TOPRIGHT", 0, 0)
	lineBar:SetPoint("BOTTOMRIGHT", linesFrame, "BOTTOMRIGHT", 0, 0)
	linesFrame:EnableMouseWheel(true)
	linesFrame:SetScript("OnMouseWheel", function(_, delta)
		lineOffset = lineOffset - delta * 3
		ResultsWindow:Refresh()
	end)

	-- the bottom: Close
	local footer = frame:CreateTexture(nil, "BORDER")
	footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, FOOTER_H - 8)
	footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, FOOTER_H - 8)
	footer:SetHeight(1)
	UI.SetTextureColor(footer, c.border)
	local closeButton = UI.NewButton(frame, 90, 32, "Close", function() ResultsWindow:Hide() end)
	closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 12)
	local hint = UI.NewText(frame, 11, c.muted)
	hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 22)
	hint:SetText("The last 15 sessions are kept. This is what every player saw.")

	frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	frame:SetScript("OnEvent", function() ResultsWindow:Refresh() end)
	restorePosition()
end

-- Opens the window on the newest session.
function ResultsWindow:Show()
	UI = ALC and ALC.UI
	if not UI then
		ASR:Print("The window needs Arbiter Loot Council (its look and widgets), which did not load.")
		return false
	end
	c = UI.color
	if not frame then build() end
	sessionIndex, selected, listOffset, lineOffset = 1, 1, 0, 0
	frame:Show()
	self:Refresh()
	return true
end

function ResultsWindow:Hide()
	if frame then frame:Hide() end
end

function ResultsWindow:Toggle()
	if frame and frame:IsShown() then self:Hide() else self:Show() end
end
