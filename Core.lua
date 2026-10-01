-- Arbiter Soft Reserve (ASR): soft reserve sessions on top of Arbiter Loot Council.
-- This is the start of the addon: the namespace, the saved data and a command that says where it stands.
-- The import of a softres.it list (SoftRes/Import.lua) and the rules for the winners (SoftRes/Rules.lua) are
-- written and tested; the windows come later.
local addonName, ASR = ...

ASR.name = addonName

local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

function ASR:Print(...)
	DEFAULT_CHAT_FRAME:AddMessage("|cff9b7bffArbiter Soft Reserve|r " .. strjoin(" ", tostringall(...)))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, name)
	if name ~= addonName then return end
	if type(ASR_DB) ~= "table" then ASR_DB = {} end
	ASR.db = ASR_DB
	ASR.version = getMetadata and getMetadata(addonName, "Version") or "?"
end)

SLASH_ARBITERSOFTRESERVE1 = "/asr"
SlashCmdList["ARBITERSOFTRESERVE"] = function()
	local list = ASR.SoftRes and ASR.SoftRes:GetList()
	ASR:Print("v" .. tostring(ASR.version) .. ": in development, nothing to use yet.")
	if list then ASR:Print(list.rows .. " reservations from " .. list.players .. " players are loaded.") end
end
