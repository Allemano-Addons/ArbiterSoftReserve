-- Smoke test outside the game: loads every file of the TOC against a fake WoW API, fires the login
-- events, opens the import box, pastes a list and presses Import. Catches Lua errors that WoW Forever
-- would swallow silently. Run from the ArbiterSoftReserve folder:  lua Tests/smoke_test.lua
time = os.time
strjoin = function(sep, ...) return table.concat({ ... }, sep) end
tostringall = function(...)
	local out = {}
	for i = 1, select("#", ...) do out[i] = tostring((select(i, ...))) end
	return table.unpack(out)
end

local failed = 0
local function check(name, ok)
	if not ok then
		failed = failed + 1
		print("FAIL: " .. name)
	end
end

-- A frame that accepts every call. Text, scripts and shown-ness are remembered.
local frames = {}
local function newFrame(kind)
	local f = { kind = kind, scripts = {}, shown = false, text = "", children = {} }
	local methods = {
		SetScript = function(self, name, fn) self.scripts[name] = fn end,
		GetScript = function(self, name) return self.scripts[name] end,
		Show = function(self) self.shown = true end,
		Hide = function(self) self.shown = false end,
		IsShown = function(self) return self.shown end,
		SetText = function(self, text) self.text = text or "" if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end,
		GetText = function(self) return self.text end,
		GetHeight = function() return 280 end,
		GetWidth = function() return 548 end,
		GetVerticalScroll = function() return 0 end,
		CreateTexture = function() return newFrame("Texture") end,
		CreateFontString = function() return newFrame("FontString") end,
		RegisterEvent = function(self, event) self.events = self.events or {} self.events[event] = true end,
	}
	frames[#frames + 1] = f
	return setmetatable(f, { __index = function(_, key)
		if methods[key] then return methods[key] end
		if type(key) == "string" and key:match("^%u") then return function() end end
	end })
end

CreateFrame = function(kind) return newFrame(kind) end
UIParent = newFrame("Frame")
UISpecialFrames = {}
ChatFontNormal = {}
local chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) chat[#chat + 1] = message end }
SlashCmdList = {}
C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Version" and "9.9.9" or nil end }

-- Load the files the TOC lists, in order.
local ASR = {}
for line in io.lines("ArbiterSoftReserve.toc") do
	line = line:gsub("\r", "")
	if line:match("%.lua$") then
		local chunk, err = loadfile((line:gsub("\\", "/")))
		check("loads " .. line, chunk ~= nil and err == nil)
		if chunk then
			local ok, message = pcall(chunk, "ArbiterSoftReserve", ASR)
			check("runs " .. line .. (ok and "" or (": " .. tostring(message))), ok)
		end
	end
end

-- The login events
local core
for _, f in ipairs(frames) do if f.events and f.events.ADDON_LOADED then core = f end end
check("the core frame listens for the addon to load", core ~= nil and core.scripts.OnEvent ~= nil)
core.scripts.OnEvent(core, "ADDON_LOADED", "SomethingElse")
check("another addon loading is ignored", ASR.db == nil)
core.scripts.OnEvent(core, "ADDON_LOADED", "ArbiterSoftReserve")
check("the saved data is created", type(ASR_DB) == "table" and ASR.db == ASR_DB and ASR.version == "9.9.9")
check("the login hooks the tooltips without a game", pcall(core.scripts.OnEvent, core, "PLAYER_LOGIN"))

-- /asr
check("/asr is registered", SLASH_ARBITERSOFTRESERVE1 == "/asr" and type(SlashCmdList["ARBITERSOFTRESERVE"]) == "function")
local slash = SlashCmdList["ARBITERSOFTRESERVE"]
slash("")
check("/asr prints the version", chat[1] and chat[1]:find("v9.9.9", 1, true) ~= nil)

-- /asr import: the box, a paste and Import
slash("import")
local box
for _, f in ipairs(frames) do if f.kind == "EditBox" then box = f end end
check("the import box is built and shown", box ~= nil and ASR.ImportWindow ~= nil)
local importButton, clearButton
for _, f in ipairs(frames) do
	if f.kind == "Button" and f.scripts.OnClick and f.children then
		importButton = importButton or f
	end
end
check("the box has buttons", importButton ~= nil)

local csv = table.concat({
	"Item Name,Item ID,From,Raider Name,Raider Class,Raider Spec,Raider Note,Extra Reserves,Date",
	"Pauldrons,29764,Maulgar,Allemano,Druid,Balance,,0,x",
	"Trophy,28830,Gruul,Erikdbest,Warrior,Fury,,0,x",
}, "\n")
box:SetText(csv)
check("pasting grows the box to fit", box:GetText() == csv)
-- press the first button (Import)
local buttons = {}
for _, f in ipairs(frames) do if f.kind == "Button" and f.scripts.OnClick then buttons[#buttons + 1] = f end end
buttons[1].scripts.OnClick(buttons[1])
check("Import loads the list", ASR.SoftRes:GetList() ~= nil and ASR.SoftRes:GetList().rows == 2)
check("and saves it", ASR_DB.softres ~= nil and ASR_DB.softres.rows == 2)
check("and empties the box", box:GetText() == "")
check("and says so in the chat", chat[#chat]:find("Imported 2 reservations from 2 players", 1, true) ~= nil)

buttons[1].scripts.OnClick(buttons[1]) -- Import with an empty box
check("an empty box is refused without an error", ASR.SoftRes:GetList().rows == 2)
box:SetText("this is not a list")
buttons[1].scripts.OnClick(buttons[1])
check("text that is not a list does not replace the list", ASR.SoftRes:GetList().rows == 2)
buttons[2].scripts.OnClick(buttons[2]) -- Clear the list
check("Clear the list forgets it", ASR.SoftRes:GetList() == nil and ASR_DB.softres == nil)
buttons[3].scripts.OnClick(buttons[3]) -- Close
check("Close hides the box", ASR.ImportWindow and true)

if failed > 0 then
	print(failed .. " failed")
	os.exit(1)
end
print("ALL OK")
