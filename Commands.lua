-- Commands: what /asr does. Kept apart from Core.lua so it can be tested outside the game.
local _, ASR = ...

local Commands = {}
ASR.Commands = Commands

local strlower = string.lower

local function status()
	local list = ASR.SoftRes:GetList()
	ASR:Print("v" .. tostring(ASR.version) .. ", in development.")
	if list then
		ASR:Print(string.format("%d reservations from %d players are loaded. The item tooltips %s them.", list.rows, list.players,
			(ASR.db and ASR.db.tooltip == false) and "do not show" or "show"))
	else
		ASR:Print("No list is loaded. Type /asr import to paste one from softres.it.")
	end
end

local HELP = {
	"/asr: the version and what is loaded",
	"/asr import: paste a softres.it CSV",
	"/asr add [item link or ID] [name]: add one reservation (name defaults to you)",
	"/asr start [items]: start a real soft reserve session in Arbiter Loot Council (loot master)",
	"/asr test [items]: try a session with made-up players (items from the list, or links/IDs)",
	"/asr session: open the session window again",
	"/asr clear: forget the list",
	"/asr tooltip on|off: the \"Soft reserved by\" line in item tooltips",
}

-- Runs a command line (what comes after /asr).
function Commands.Run(text)
	local word, rest = (text or ""):match("^%s*(%S*)%s*(.-)%s*$")
	word = strlower(word or "")
	if word == "" then
		status()
	elseif word == "import" then
		ASR.ImportWindow:Show()
	elseif word == "start" then
		-- /asr start [items]: a real soft reserve session in Arbiter Loot Council (loot master)
		local Controller = ASR.SoftRes.Controller
		local ids = Controller.ParseItemIDs(rest)
		if #ids == 0 then ids = Controller.ItemsOfList() end
		if #ids == 0 then
			ASR:Print("There are no items. Import a list first, or give items: /asr start [item links or IDs]")
		else
			local ok, message = ASR.SoftRes.Bridge.Start(ids)
			if not ok then ASR:Print(message or "Could not start the session.") end
		end
	elseif word == "test" then
		-- /asr test [items]: a test session with made-up players next to the real reservers, to try the whole flow
		local Controller = ASR.SoftRes.Controller
		local ids = Controller.ParseItemIDs(rest)
		if #ids == 0 then ids = Controller.ItemsOfList() end
		if Controller.live then
			ASR:Print("A soft reserve session is running in Arbiter Loot Council. End it first (/alc cancel).")
		elseif #ids == 0 then
			ASR:Print("There are no items. Import a list first, or give items: /asr test [item links or IDs]")
		else
			Controller:Start(ids)
			Controller:FillTest()
			ASR:Print(string.format("A test session with %d items. The players next to the real reservers are made up.", #ids))
			ASR.SessionWindow:Show()
		end
	elseif word == "session" then
		if not ASR.SessionWindow:Show() then ASR:Print("There is no session. Start a test with /asr test.") end
	elseif word == "add" then
		-- /asr add [item link or item ID] [name]: one reservation, for trying the tooltip with an item you have
		local itemID = tonumber(rest:match("item:(%d+)") or rest:match("^(%d+)"))
		-- the name is what is left when the link (any colour code style) and a bare ID are taken away
		local name = ASR.SoftRes.CleanName(rest):gsub("^%d+", ""):match("^%s*(.-)%s*$")
		if name == "" and UnitName then name = UnitName("player") end
		local list, message = ASR.SoftRes:Add(itemID, name)
		if list then
			ASR:Print(string.format("Added item %d for %s. %d reservations are loaded.", itemID, name, list.rows))
		else
			ASR:Print((message or "Could not add it.") .. " Usage: /asr add [shift-click an item] [name]")
		end
	elseif word == "clear" then
		ASR.SoftRes:Clear()
		ASR:Print("The list was cleared.")
	elseif word == "tooltip" then
		rest = strlower(rest)
		if rest == "on" or rest == "off" then
			if ASR.db then ASR.db.tooltip = rest == "on" end
			ASR:Print("The item tooltips " .. (rest == "on" and "show" or "do not show") .. " who reserved an item.")
		else
			ASR:Print("Usage: /asr tooltip on|off")
		end
	else
		ASR:Print("Commands:")
		for _, line in ipairs(HELP) do ASR:Print("  " .. line) end
	end
end
