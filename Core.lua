-- Arbiter Soft Reserve (ASR): soft reserve for Arbiter Loot Council.
-- This file is the namespace, the saved data and the /asr command. The list (SoftRes/Import.lua), the
-- tooltip line (SoftRes/Tooltip.lua) and the import box (ImportWindow.lua) are what exists so far.
local addonName, ASR = ...

ASR.name = addonName

local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

function ASR:Print(...)
	DEFAULT_CHAT_FRAME:AddMessage("|cff9b7bffArbiter Soft Reserve|r " .. strjoin(" ", tostringall(...)))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name ~= addonName then return end
		if type(ASR_DB) ~= "table" then ASR_DB = {} end
		ASR.db = ASR_DB
		ASR.version = getMetadata and getMetadata(addonName, "Version") or "?"
	elseif event == "PLAYER_LOGIN" then
		ASR.SoftRes.InstallTooltip()
		-- Tell ALC we are here, when it is new enough to ask (ALC 0.3.4 has no API yet; nothing in ASR needs it so far).
		if ALC and ALC.RegisterExtension then ALC.RegisterExtension("ArbiterSoftReserve", ASR.version) end
		pcall(ASR.SoftRes.Bridge.Init)
	end
end)

SLASH_ARBITERSOFTRESERVE1 = "/asr"
SlashCmdList["ARBITERSOFTRESERVE"] = function(text) ASR.Commands.Run(text) end
