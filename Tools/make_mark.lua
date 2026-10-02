-- Makes ASR's logo: Arbiter Loot Council's mark with the green part recoloured purple (9B7BFF).
-- Run from the ArbiterSoftReserve folder (needs the sibling ArbiterLootCouncil repo):  lua Tools/make_mark.lua
local SRC = "../ArbiterLootCouncil/Media/Logo/"
local DST = "Media/Logo/"
local PURPLE = { 155, 123, 255 }

local function readf(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local function writef(p, s) local f = assert(io.open(p, "wb")) f:write(s) f:close() end

-- The TGA files are uncompressed 32 bit BGRA. A pixel is "green" when green leads clearly; its alpha stays,
-- so the soft edges stay soft.
local function recolor(data)
	local idlen = data:byte(1)
	local w, h = data:byte(13) + data:byte(14) * 256, data:byte(15) + data:byte(16) * 256
	assert(data:byte(3) == 2 and data:byte(17) == 32, "expected an uncompressed 32 bit TGA")
	local off = 18 + idlen
	local out = { data:sub(1, off) }
	for p = 0, w * h - 1 do
		local i = off + p * 4 + 1
		local b, g, r, a = data:byte(i, i + 3)
		if g - r > 25 and g - b > 15 then b, g, r = PURPLE[3], PURPLE[2], PURPLE[1] end
		out[#out + 1] = string.char(b, g, r, a)
	end
	out[#out + 1] = data:sub(off + w * h * 4 + 1)
	return table.concat(out)
end

for _, size in ipairs({ 64 }) do
	writef(DST .. "asr_mark_" .. size .. ".tga", recolor(readf(SRC .. "alc_mark_" .. size .. ".tga")))
end
print("made Media/Logo/asr_mark_64.tga")
