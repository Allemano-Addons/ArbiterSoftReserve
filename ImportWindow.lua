-- ImportWindow: a box to paste the softres.it CSV into. Opened by /asr import. It shows the loaded list as
-- CSV, so the list can be edited and imported again.
--
-- The look is Arbiter Loot Council's (ASR needs ALC anyway): the window is built from ALC's own widgets, with
-- ASR's purple mark. The multi-line edit box is built like the one in Allemano Raid Tools, which is known to
-- take typing and selection in the game.
local _, ASR = ...

local ImportWindow = {}
ASR.ImportWindow = ImportWindow

local WIDTH, HEIGHT, PAD, HEADER_H = 640, 480, 16, 52
local MEDIA = "Interface\\AddOns\\ArbiterSoftReserve\\Media\\"
local GREEN = { 0.30, 0.75, 0.40, 1 }
local RED = { 0.85, 0.32, 0.30, 1 }

local frame, edit, status, UI, c

local function setStatus(text, color)
	color = color or c.muted
	status:SetTextColor(color[1], color[2], color[3], 1)
	status:SetText(text)
end

local function doImport()
	local list, message = ASR.SoftRes:Import(edit:GetText() or "")
	if not list then
		setStatus(message or "Nothing was imported.", RED)
		return
	end
	setStatus(string.format("Imported %d reservations from %d players%s.", list.rows, list.players,
		list.skipped > 0 and (" (" .. list.skipped .. " lines skipped)") or ""), GREEN)
	ASR:Print(string.format("Imported %d reservations from %d players.", list.rows, list.players))
end

-- The box shows the loaded list as CSV, so it can be edited and imported again.
local function showList()
	edit:SetText(ASR.SoftRes:ToCSV())
	edit:SetCursorPosition(0)
end

local function savePosition()
	if not ASR.db then return end
	local point, _, relPoint, x, y = frame:GetPoint()
	ASR.db.windows = ASR.db.windows or {}
	ASR.db.windows.import = { point = point, relPoint = relPoint, x = x, y = y }
end

local function restorePosition()
	frame:ClearAllPoints()
	local pos = ASR.db and ASR.db.windows and ASR.db.windows.import
	if pos and pos.point then
		frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	end
end

local function build()
	frame = CreateFrame("Frame", "ArbiterSoftReserveImport", UIParent)
	UI.RegisterScaled(frame)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("HIGH")
	frame:SetFrameLevel(30)
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:Hide()
	if UISpecialFrames then table.insert(UISpecialFrames, "ArbiterSoftReserveImport") end -- Esc closes it

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
	title:SetText("SOFT RESERVE: IMPORT")

	local close = CreateFrame("Button", nil, bar)
	close:SetSize(28, 28)
	close:SetPoint("RIGHT", bar, "RIGHT", -12, 0)
	close.text = UI.NewText(close, 22, c.muted, "CENTER")
	close.text:SetPoint("CENTER", 0, 0)
	close.text:SetText("\195\151")
	close:SetScript("OnEnter", function(self) self.text:SetTextColor(c.text[1], c.text[2], c.text[3], 1) end)
	close:SetScript("OnLeave", function(self) self.text:SetTextColor(c.muted[1], c.muted[2], c.muted[3], 1) end)
	close:SetScript("OnClick", function() frame:Hide() end)

	local divider = frame:CreateTexture(nil, "BORDER")
	divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -HEADER_H)
	divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -HEADER_H)
	divider:SetHeight(1)
	UI.SetTextureColor(divider, c.border)

	local help = UI.NewText(frame, 12, c.muted)
	help:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(HEADER_H + 12))
	help:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
	help:SetWordWrap(true)
	help:SetText("On softres.it, open your raid and choose Export, then CSV. Copy the text, paste it here and press Import. A new import replaces the old list. The text can be edited first.")

	-- The multi-line box: the surrounding frame takes the click and focuses the EditBox, the EditBox sizes itself
	-- to its text.
	local box = CreateFrame("Frame", nil, frame)
	box:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(HEADER_H + 54))
	box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 96)
	local boxBg = UI.NewFill(box, 6)
	UI.SetTextureColor(boxBg, c.panel)
	local boxBorder = UI.AddBorder(box, c.border, 1, 6)
	local scroll = CreateFrame("ScrollFrame", nil, box)
	scroll:SetPoint("TOPLEFT", 10, -8)
	scroll:SetPoint("BOTTOMRIGHT", -10, 8)

	edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetFontObject(ChatFontNormal or GameFontHighlight)
	edit:SetTextColor(c.text[1], c.text[2], c.text[3], 1)
	edit:SetAutoFocus(false)
	edit:SetMaxLetters(0)
	edit:SetWidth(200)
	scroll:SetScrollChild(edit)
	scroll:SetScript("OnSizeChanged", function(self, w) edit:SetWidth(math.max(50, w or self:GetWidth())) end)
	edit:SetScript("OnCursorChanged", function(_, _, y, _, h)
		local top, height = scroll:GetVerticalScroll(), scroll:GetHeight()
		y = -y
		if y < top then
			scroll:SetVerticalScroll(y)
		elseif y + h > top + height then
			scroll:SetVerticalScroll(y + h - height)
		end
	end)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEditFocusGained", function() boxBorder:SetColor(c.gold) end)
	edit:SetScript("OnEditFocusLost", function() boxBorder:SetColor(c.border) end)
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function() edit:SetFocus() end)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = math.max(0, edit:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
	end)

	status = UI.NewText(frame, 13, c.muted)
	status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 66)
	status:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 66)

	local footer = frame:CreateTexture(nil, "BORDER")
	footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 56)
	footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 56)
	footer:SetHeight(1)
	UI.SetTextureColor(footer, c.border)

	local importButton = UI.NewButton(frame, 120, 32, "Import", doImport)
	importButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 12)
	local clearButton = UI.NewButton(frame, 140, 32, "Clear the list", function()
		ASR.SoftRes:Clear()
		showList()
		setStatus("The list was cleared.")
	end)
	clearButton:SetPoint("LEFT", importButton, "RIGHT", 8, 0)
	local closeButton = UI.NewButton(frame, 90, 32, "Close", function() frame:Hide() end)
	closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 12)
	restorePosition()
end

function ImportWindow:Show()
	UI = ALC and ALC.UI
	if not UI then
		ASR:Print("The window needs Arbiter Loot Council (its look and widgets), which did not load.")
		return
	end
	c = UI.color
	if not frame then build() end
	local list = ASR.SoftRes:GetList()
	setStatus(list and string.format("Loaded: %d reservations from %d players.", list.rows, list.players) or "No list is loaded.")
	showList()
	frame:Show()
	edit:SetFocus()
end

function ImportWindow:Hide()
	if frame then frame:Hide() end
end
