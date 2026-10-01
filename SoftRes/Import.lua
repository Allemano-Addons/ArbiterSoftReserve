-- SoftRes / Import: reads a soft-reserve list (the CSV export of softres.it) and answers "who reserved
-- this item?". Nothing here talks to the game or to other players; it is plain data and text, so it can
-- be tested outside the game. The rules that turn answers and rolls into winners are in Rules.lua.
--
-- The CSV has a header line and one line per reservation:
--   Item Name,Item ID,From,Raider Name,Raider Class,Raider Spec,Raider Note,Extra Reserves,Date
-- Fields may be put in double quotes (a quote inside is written twice).

local _, ASR = ...

local strlower, strmatch = string.lower, string.match

local SoftRes = ASR.SoftRes or {}
ASR.SoftRes = SoftRes

local list -- the imported list in memory: { importedAt, reserves = { [itemID] = { { name, class, spec, note, extra } } }, ... }

--------------------------------------------------------------------------------
-- CSV
--------------------------------------------------------------------------------

-- The fields of one CSV line.
local function splitLine(line)
	local fields, i, n = {}, 1, #line
	while i <= n + 1 do
		local c = line:sub(i, i)
		if c == '"' then
			local value = {}
			i = i + 1
			while i <= n do
				local ch = line:sub(i, i)
				if ch == '"' then
					if line:sub(i + 1, i + 1) == '"' then
						value[#value + 1] = '"'
						i = i + 2
					else
						i = i + 1
						break
					end
				else
					value[#value + 1] = ch
					i = i + 1
				end
			end
			fields[#fields + 1] = table.concat(value)
			-- skip to the comma after the closing quote
			while i <= n and line:sub(i, i) ~= "," do i = i + 1 end
			i = i + 1
		else
			local comma = line:find(",", i, true)
			if comma then
				fields[#fields + 1] = line:sub(i, comma - 1)
				i = comma + 1
			else
				fields[#fields + 1] = line:sub(i)
				break
			end
		end
	end
	return fields
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- Reads the CSV text. Returns the list { reserves, players, rows, skipped } or nil and a message.
function SoftRes.ParseCSV(text)
	if type(text) ~= "string" or text:find("^%s*$") then return nil, "There is nothing to read." end
	local columns
	local reserves, players, rows, skipped = {}, {}, 0, 0
	for rawLine in text:gmatch("[^\r\n]+") do
		local line = rawLine:gsub("^\239\187\191", "") -- a byte order mark at the very start
		if not columns then
			columns = {}
			for index, name in ipairs(splitLine(line)) do columns[strlower(trim(name))] = index end
			if not (columns["item id"] and columns["raider name"]) then
				return nil, "That does not look like a softres.it CSV: the columns Item ID and Raider Name are missing."
			end
		elseif not line:find("^%s*$") then
			local fields = splitLine(line)
			local itemID = tonumber(trim(fields[columns["item id"]] or ""))
			local name = trim(fields[columns["raider name"]] or "")
			if itemID and itemID > 0 and itemID == math.floor(itemID) and name ~= "" then
				local function field(key) return trim(fields[columns[key] or 0] or "") end
				local entry = {
					name = name,
					class = field("raider class"),
					spec = field("raider spec"),
					note = field("raider note"),
					extra = tonumber(field("extra reserves")) or 0,
				}
				local forItem = reserves[itemID]
				if not forItem then
					forItem = {}
					reserves[itemID] = forItem
				end
				forItem[#forItem + 1] = entry
				players[strlower(name)] = true
				rows = rows + 1
			else
				skipped = skipped + 1
			end
		end
	end
	if rows == 0 then return nil, "No reservations were found." end
	local playerCount = 0
	for _ in pairs(players) do playerCount = playerCount + 1 end
	return { reserves = reserves, players = playerCount, rows = rows, skipped = skipped }
end

--------------------------------------------------------------------------------
-- The list the loot master has loaded
--------------------------------------------------------------------------------

-- Reads the CSV and keeps it (also saved in ASR_DB). Returns the list, or nil and a message.
function SoftRes:Import(text)
	local parsed, message = SoftRes.ParseCSV(text)
	if not parsed then return nil, message end
	parsed.importedAt = time()
	list = parsed
	if ASR.db then ASR.db.softres = parsed end
	return parsed
end

-- The loaded list (from memory, else from the saved one), or nil.
function SoftRes:GetList()
	if not list and ASR.db then list = ASR.db.softres end
	return list
end

function SoftRes:Clear()
	list = nil
	if ASR.db then ASR.db.softres = nil end
end

-- A reserve may carry only the first name ("Allemano"), a character on Forever has a surname
-- ("Allemano Moo"): they are the same when the first names match.
function SoftRes.SameCharacter(reserveName, characterName)
	local a, b = strlower(reserveName or ""), strlower(characterName or "")
	if a == "" or b == "" then return false end
	if a == b then return true end
	return strmatch(b, "^(%S+)") == a or strmatch(a, "^(%S+)") == b
end

-- Everybody who reserved an item: a list of { name, class, spec, note, extra }.
function SoftRes:GetReservers(itemID)
	local current = self:GetList()
	return current and current.reserves[itemID] or {}
end

-- Whether this character reserved the item.
function SoftRes:IsReserver(characterName, itemID)
	for _, entry in ipairs(self:GetReservers(itemID)) do
		if SoftRes.SameCharacter(entry.name, characterName) then return true end
	end
	return false
end
