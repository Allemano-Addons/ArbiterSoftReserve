-- SoftRes / Tooltip: a line in every item tooltip that says who soft reserved the item, as Gargul does:
--   Soft reserved by: Allemano, Erikdbest (+2 more)
-- The text is made by a plain function (TooltipText, tested outside the game); Install hooks it into the
-- game's tooltips. Forever's tooltips follow the newer interface (TooltipDataProcessor), with the older
-- OnTooltipSetItem script as the fall-back.

local _, ASR = ...

local SoftRes = ASR.SoftRes or {}
ASR.SoftRes = SoftRes

local MAX_NAMES = 6 -- how many names the line holds before it says "+N more"

-- "Death Knight" -> "DEATHKNIGHT": the key of RAID_CLASS_COLORS.
local function classToken(class)
	return (string.upper(class or ""):gsub("[^A-Z]", ""))
end

-- The tooltip line for an item, or nil when nobody reserved it. `classColors` (optional) maps a class
-- token to a hex colour ("C69B6D"), so the names get the colour of their class.
function SoftRes.TooltipText(itemID, classColors)
	local reservers = SoftRes:GetReservers(itemID)
	if #reservers == 0 then return nil end
	local names, shown = {}, math.min(#reservers, MAX_NAMES)
	for i = 1, shown do
		local entry = reservers[i]
		local color = classColors and classColors[classToken(entry.class)]
		names[#names + 1] = color and ("|cff" .. color .. entry.name .. "|r") or entry.name
	end
	local text = "Soft reserved by: " .. table.concat(names, ", ")
	if #reservers > shown then text = text .. " (+" .. (#reservers - shown) .. " more)" end
	return text
end

-- The colours of the game's classes as hex, from RAID_CLASS_COLORS (nil outside the game).
local function gameClassColors()
	if not RAID_CLASS_COLORS then return nil end
	local colors = {}
	for token, c in pairs(RAID_CLASS_COLORS) do
		if type(c) == "table" and c.r then
			colors[token] = string.format("%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
		end
	end
	return colors
end

local function addLine(tooltip, itemID)
	if not (ASR.db and ASR.db.tooltip ~= false) then return end
	if type(itemID) ~= "number" or (issecretvalue and issecretvalue(itemID)) then return end
	local text = SoftRes.TooltipText(itemID, gameClassColors())
	if not text then return end
	tooltip:AddLine(text, 0.62, 0.48, 1, true)
end

local installed = false

-- Hooks the tooltips. Safe to call twice.
function SoftRes.InstallTooltip()
	if installed then return end
	installed = true
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
			pcall(function()
				local itemID = data and data.id
				if itemID and tooltip and tooltip.AddLine then addLine(tooltip, itemID) end
			end)
		end)
	elseif GameTooltip and GameTooltip.HookScript then
		local function hook(tooltip)
			tooltip:HookScript("OnTooltipSetItem", function(self)
				pcall(function()
					local _, link = self:GetItem()
					local itemID = link and tonumber(link:match("item:(%d+)"))
					if itemID then addLine(self, itemID) end
				end)
			end)
		end
		hook(GameTooltip)
		if ItemRefTooltip then hook(ItemRefTooltip) end
	end
end
