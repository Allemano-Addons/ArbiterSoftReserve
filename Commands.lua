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
