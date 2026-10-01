-- ImportWindow: a box to paste the softres.it CSV into. Opened by /asr import.
-- Plain frames and textures only (no templates), so it looks the same everywhere and cannot fail on a
-- missing template.
local _, ASR = ...

local ImportWindow = {}
ASR.ImportWindow = ImportWindow

local WIDTH, HEIGHT = 600, 420
local frame, edit, status

local function color(texture, r, g, b, a) texture:SetColorTexture(r, g, b, a or 1) end

local function newButton(parent, label, width, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, 28)
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	color(button.bg, 0.16, 0.17, 0.2)
	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	button.text:SetPoint("CENTER")
	button.text:SetText(label)
	button:SetScript("OnEnter", function(self) color(self.bg, 0.24, 0.25, 0.3) end)
	button:SetScript("OnLeave", function(self) color(self.bg, 0.16, 0.17, 0.2) end)
	button:SetScript("OnClick", onClick)
	return button
end

-- A rough height for the pasted text, so the scroll frame can scroll all of it.
local function fitEdit()
	local text = edit:GetText() or ""
	local lines = 0
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		lines = lines + math.max(1, math.ceil(#line / 70))
	end
	edit:SetHeight(math.max(280, lines * 14 + 24))
end

local function doImport()
	local list, message = ASR.SoftRes:Import(edit:GetText() or "")
	if not list then
		status:SetTextColor(1, 0.4, 0.4)
		status:SetText(message or "Nothing was imported.")
		return
	end
	status:SetTextColor(0.5, 0.9, 0.55)
	status:SetText(string.format("Imported %d reservations from %d players%s.", list.rows, list.players,
		list.skipped > 0 and (" (" .. list.skipped .. " lines skipped)") or ""))
	edit:SetText("")
	fitEdit()
	ASR:Print(string.format("Imported %d reservations from %d players.", list.rows, list.players))
end

local function build()
	frame = CreateFrame("Frame", "ArbiterSoftReserveImport", UIParent)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	frame:Hide()
	if UISpecialFrames then table.insert(UISpecialFrames, "ArbiterSoftReserveImport") end -- Esc closes it

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	color(bg, 0.07, 0.075, 0.09, 0.97)
	for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", WIDTH, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", WIDTH, 1 } }) do
		local line = frame:CreateTexture(nil, "BORDER")
		line:SetPoint(edge[1])
		line:SetPoint(edge[2])
		line:SetHeight(1)
		color(line, 0.35, 0.3, 0.55)
	end

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetText("Arbiter Soft Reserve: import")

	local help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", 16, -42)
	help:SetPoint("TOPRIGHT", -16, -42)
	help:SetJustifyH("LEFT")
	help:SetText("On softres.it, open your raid and choose Export, then CSV. Copy the text, paste it here and press Import. A new import replaces the old list.")

	local scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetPoint("TOPLEFT", 16, -80)
	scroll:SetPoint("BOTTOMRIGHT", -16, 90)
	local scrollBg = scroll:CreateTexture(nil, "BACKGROUND")
	scrollBg:SetAllPoints()
	color(scrollBg, 0.03, 0.03, 0.04, 1)

	edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetFontObject(ChatFontNormal or GameFontHighlight)
	edit:SetAutoFocus(false)
	edit:SetWidth(WIDTH - 52)
	edit:SetHeight(280)
	edit:SetMaxLetters(0)
	edit:SetTextInsets(6, 6, 4, 4)
	scroll:SetScrollChild(edit)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnTextChanged", fitEdit)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = math.max(0, edit:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
	end)
	scroll:EnableMouse(true)
	scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)

	status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	status:SetPoint("BOTTOMLEFT", 16, 56)
	status:SetPoint("BOTTOMRIGHT", -16, 56)
	status:SetJustifyH("LEFT")
	status:SetText("")

	local importButton = newButton(frame, "Import", 110, doImport)
	importButton:SetPoint("BOTTOMLEFT", 16, 16)
	local clearButton = newButton(frame, "Clear the list", 130, function()
		ASR.SoftRes:Clear()
		status:SetTextColor(0.8, 0.8, 0.8)
		status:SetText("The list was cleared.")
	end)
	clearButton:SetPoint("LEFT", importButton, "RIGHT", 8, 0)
	local closeButton = newButton(frame, "Close", 90, function() frame:Hide() end)
	closeButton:SetPoint("BOTTOMRIGHT", -16, 16)
end

function ImportWindow:Show()
	if not frame then build() end
	local list = ASR.SoftRes:GetList()
	status:SetTextColor(0.8, 0.8, 0.8)
	status:SetText(list and string.format("Loaded: %d reservations from %d players.", list.rows, list.players) or "No list is loaded.")
	frame:Show()
	edit:SetFocus()
end

function ImportWindow:Hide()
	if frame then frame:Hide() end
end
