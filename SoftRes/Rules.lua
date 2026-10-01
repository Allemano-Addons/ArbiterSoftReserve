-- SoftRes / Rules: who wins what, once everybody has answered. Plain functions, no game and no
-- chat, so they can be tested outside the game. The loot master's addon rolls (the game's /roll is not
-- readable for addons in instances), and every roll is shown to everybody in the Result window.
--
-- An item has `copies` (how many there are) and `entries`, one per player who answered:
--   { name, answer = "MS" | "OS" | "PASS", roll = number, reserved = true | false, rerolls = { ... } }
--
-- The order of the claims:
--   1. Those who reserved the item and did not pass roll for it. (A reserver who answered OS still counts as a
--      reserver: the reserve decides, not the button.)
--   2. Copies left over (fewer reservers than copies) go to those who did not reserve it, MS before OS.
--   3. Copies nobody claims are `unclaimed`.
-- With more claimants than copies the highest rolls win. A tie at the edge is not decided by the addon:
-- it is returned in `ties` and the loot master presses Reroll, which rolls again for those players only.

local _, ASR = ...

local SoftRes = ASR.SoftRes or {}
ASR.SoftRes = SoftRes

local sort = table.sort

-- 1 to 100, or whatever `random` gives (tests pass their own).
function SoftRes.Roll(random)
	return (random or math.random)(1, 100)
end

-- Gives a roll to every entry that has none. Returns how many were rolled.
function SoftRes.RollAll(entries, random)
	local count = 0
	for _, entry in ipairs(entries) do
		if entry.answer ~= "PASS" and entry.roll == nil then
			entry.roll = SoftRes.Roll(random)
			count = count + 1
		end
	end
	return count
end

-- Rolls again for the named players (the ones that tied). Their new rolls only count among themselves.
function SoftRes.Reroll(entries, names, random)
	local wanted = {}
	for _, name in ipairs(names) do wanted[name] = true end
	for _, entry in ipairs(entries) do
		if wanted[entry.name] then
			entry.rerolls = entry.rerolls or {}
			entry.rerolls[#entry.rerolls + 1] = SoftRes.Roll(random)
		end
	end
end

-- The numbers an entry is ranked by: the roll, then each reroll.
local function key(entry)
	local k = { entry.roll or 0 }
	for _, r in ipairs(entry.rerolls or {}) do k[#k + 1] = r end
	return k
end

-- 1 if a ranks above b, -1 if below, 0 if equal.
local function compare(a, b)
	local ka, kb = key(a), key(b)
	for i = 1, math.max(#ka, #kb) do
		local x, y = ka[i] or -1, kb[i] or -1
		if x ~= y then return x > y and 1 or -1 end
	end
	return 0
end

local function ranked(pool)
	sort(pool, function(a, b)
		local c = compare(a, b)
		if c ~= 0 then return c > 0 end
		return a.name < b.name
	end)
	return pool
end

-- Works out the winners of one item. Returns
--   { winners = { { name, roll, via = "SR" | "MS" | "OS" } }, ties = { { via, names, slots } }, unclaimed = n }
-- `ties` is empty when everything is decided.
function SoftRes.Resolve(item)
	local copies = item.copies or 1
	local reserved, openMS, openOS = {}, {}, {}
	for _, entry in ipairs(item.entries) do
		if entry.answer ~= "PASS" then
			if entry.reserved then
				reserved[#reserved + 1] = entry
			elseif entry.answer == "MS" then
				openMS[#openMS + 1] = entry
			elseif entry.answer == "OS" then
				openOS[#openOS + 1] = entry
			end
		end
	end

	local result = { winners = {}, ties = {}, unclaimed = 0 }
	local remaining = copies
	local blocked = false

	local function claim(pool, via)
		if blocked or remaining <= 0 or #pool == 0 then return end
		ranked(pool)
		if #pool <= remaining then
			for _, entry in ipairs(pool) do
				result.winners[#result.winners + 1] = { name = entry.name, roll = entry.roll, rerolls = entry.rerolls, via = via }
			end
			remaining = remaining - #pool
			return
		end
		-- more claimants than copies: the highest rolls win, a tie at the edge waits for a reroll
		local edge = pool[remaining]
		local above, tied = 0, {}
		for _, entry in ipairs(pool) do
			local c = compare(entry, edge)
			if c > 0 then above = above + 1 elseif c == 0 then tied[#tied + 1] = entry.name end
		end
		local slots = remaining - above
		for i = 1, above do
			local entry = pool[i]
			result.winners[#result.winners + 1] = { name = entry.name, roll = entry.roll, rerolls = entry.rerolls, via = via }
		end
		if #tied > slots then
			result.ties[#result.ties + 1] = { via = via, names = tied, slots = slots }
			blocked = true
		else
			for i = above + 1, remaining do
				local entry = pool[i]
				result.winners[#result.winners + 1] = { name = entry.name, roll = entry.roll, rerolls = entry.rerolls, via = via }
			end
		end
		remaining = 0
	end

	claim(reserved, "SR")
	claim(openMS, "MS")
	claim(openOS, "OS")
	result.unclaimed = blocked and 0 or remaining
	return result
end
