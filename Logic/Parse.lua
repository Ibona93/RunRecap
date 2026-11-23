local _, ns = ...

--[[
Parsing of chat lines and item links. Patterns are built from the client's global strings
(LOOT_ITEM, LOOT_ROLL_WON, LOOT_MONEY_SPLIT ...), never from fixed texts, so every client
language works. Pure logic, no frames - covered by tests/run.lua with the deDE strings the
probe recorded in the Forever client.
]]

local Parse = {}
ns.Parse = Parse

-------------------------------------------------------------------------------
-- Format string -> Lua pattern
-------------------------------------------------------------------------------

-- "%s bekommt Beute: %s." -> "^(.-) bekommt Beute: (.-)%.$", { 1, 2 }
-- Positional arguments ("%2$s") are supported: order[capture] = argument number.
function Parse.FormatToPattern(fmt, anchored)
	if type(fmt) ~= "string" or fmt == "" then return nil end
	local out, order, i, n, seq = {}, {}, 1, #fmt, 0
	while i <= n do
		local c = fmt:sub(i, i)
		if c == "%" then
			local nxt = fmt:sub(i + 1, i + 1)
			if nxt == "%" then
				out[#out + 1] = "%%"
				i = i + 2
			else
				local pos, kind, len = fmt:match("^(%d)%$([sd])()", i + 1)
				if pos then
					order[#order + 1] = tonumber(pos)
					i = len
				else
					kind = fmt:match("^[sd]", i + 1)
					if not kind then return nil end
					seq = seq + 1
					order[#order + 1] = seq
					i = i + 2
				end
				out[#out + 1] = kind == "d" and "(%-?%d+)" or "(.-)"
			end
		else
			out[#out + 1] = c:find("[%^%$%(%)%.%[%]%*%+%-%?]") and ("%" .. c) or c
			i = i + 1
		end
	end
	local pattern = table.concat(out)
	if anchored ~= false then pattern = "^" .. pattern .. "$" end
	return pattern, order
end

-- Matches `text` against a format string; returns the arguments in the format's own order.
local cache = {}
function Parse.Match(fmt, text, anchored)
	if type(fmt) ~= "string" or type(text) ~= "string" then return nil end
	local id = fmt .. (anchored == false and "\1" or "")
	local entry = cache[id]
	if entry == nil then
		local pattern, order = Parse.FormatToPattern(fmt, anchored)
		entry = pattern and { pattern = pattern, order = order } or false
		cache[id] = entry
	end
	if not entry then return nil end
	local caps = { text:match(entry.pattern) }
	if caps[1] == nil then return nil end
	local args = {}
	for capture, argNumber in ipairs(entry.order) do args[argNumber] = caps[capture] end
	return args
end

-------------------------------------------------------------------------------
-- Names and item links
-------------------------------------------------------------------------------

-- "Name-Realm" -> "Name" (Forever names may contain spaces, never a dash).
function Parse.ShortName(name)
	if type(name) ~= "string" then return nil end
	return (name:gsub("%-.*$", ""))
end

function Parse.ItemID(link)
	if type(link) ~= "string" then return nil end
	return tonumber(link:match("|Hitem:(%d+)"))
end

function Parse.ItemName(link)
	if type(link) ~= "string" then return nil end
	return link:match("|h%[(.-)%]|h")
end

local COLOR_QUALITY = {
	["9d9d9d"] = 0, ffffff = 1, ["1eff00"] = 2, ["0070dd"] = 3, a335ee = 4, ff8000 = 5, e6cc80 = 6, ["00ccff"] = 7,
}

-- Quality from the link: Forever's "|cnIQ3:" form or the classic "|cff0070dd" colour.
function Parse.ItemQuality(link)
	if type(link) ~= "string" then return nil end
	local iq = link:match("|cnIQ(%d+):")
	if iq then return tonumber(iq) end
	local color = link:match("|c%x%x(%x%x%x%x%x%x)")
	if color then return COLOR_QUALITY[color:lower()] end
	return nil
end

-- Only the item link part of a longer text ("[Beute]: |cnIQ2:|Hitem:...|h[X]|h|r").
function Parse.FirstItemLink(text)
	if type(text) ~= "string" then return nil end
	return text:match("(|c[^|]*|Hitem:.-|h%[.-%]|h|r)") or text:match("(|Hitem:.-|h%[.-%]|h)")
end

-------------------------------------------------------------------------------
-- Loot lines (CHAT_MSG_LOOT)
-------------------------------------------------------------------------------

-- Only real loot. LOOT_ITEM_PUSHED* (quest rewards) and LOOT_ITEM_CREATED* (crafting,
-- "Ihr stellt her") are left out on purpose. MULTIPLE before the single forms.
Parse.LOOT_FORMATS = {
	{ key = "LOOT_ITEM_SELF_MULTIPLE", self = true, item = 1, count = 2 },
	{ key = "LOOT_ITEM_MULTIPLE", player = 1, item = 2, count = 3 },
	{ key = "LOOT_ITEM_SELF", self = true, item = 1 },
	{ key = "LOOT_ITEM", player = 1, item = 2 },
}

-- Returns { player = name or nil (self), self = bool, link, count } or nil.
function Parse.Loot(msg, G)
	G = G or _G
	if type(msg) ~= "string" or msg:find("|HlootHistory:") then return nil end
	for _, spec in ipairs(Parse.LOOT_FORMATS) do
		local args = Parse.Match(G[spec.key], msg)
		if args then
			local link = args[spec.item]
			if link and link:find("|Hitem:") then
				return {
					self = spec.self or false,
					player = spec.player and Parse.ShortName(args[spec.player]) or nil,
					link = link,
					count = spec.count and tonumber(args[spec.count]) or 1,
				}
			end
		end
	end
	return nil
end

-------------------------------------------------------------------------------
-- Roll lines (CHAT_MSG_LOOT with |HlootHistory:<id>|h)
-------------------------------------------------------------------------------

-- kind: "start" (item announced), "choice" (need/greed/pass chosen), "roll" (number rolled),
-- "won", "allpassed". Argument numbers as in Blizzard's format calls.
Parse.ROLL_FORMATS = {
	{ key = "LOOT_ROLL_ROLLED_NEED", kind = "roll", roll = "need", id = 1, value = 2, item = 3, player = 4 },
	{ key = "LOOT_ROLL_ROLLED_GREED", kind = "roll", roll = "greed", id = 1, value = 2, item = 3, player = 4 },
	{ key = "LOOT_ROLL_ROLLED_DE", kind = "roll", roll = "disenchant", id = 1, value = 2, item = 3, player = 4 },
	{ key = "LOOT_ROLL_ROLLED_TRANSMOG", kind = "roll", roll = "transmog", id = 1, value = 2, item = 3, player = 4 },
	{ key = "LOOT_ROLL_WON_NO_SPAM_NEED", kind = "won", roll = "need", id = 1, player = 2, value = 3, item = 4 },
	{ key = "LOOT_ROLL_WON_NO_SPAM_GREED", kind = "won", roll = "greed", id = 1, player = 2, value = 3, item = 4 },
	{ key = "LOOT_ROLL_YOU_WON", kind = "won", self = true, id = 1, item = 2 },
	{ key = "LOOT_ROLL_WON", kind = "won", id = 1, player = 2, item = 3 },
	{ key = "LOOT_ROLL_ALL_PASSED", kind = "allpassed", id = 1, item = 2 },
	{ key = "LOOT_ROLL_PASSED_SELF", kind = "choice", roll = "pass", self = true, id = 1, item = 2 },
	{ key = "LOOT_ROLL_PASSED", kind = "choice", roll = "pass", id = 1, player = 2, item = 3 },
	{ key = "LOOT_ROLL_NEED_SELF", kind = "choice", roll = "need", self = true, id = 1, item = 2 },
	{ key = "LOOT_ROLL_NEED", kind = "choice", roll = "need", id = 1, player = 2, item = 3 },
	{ key = "LOOT_ROLL_GREED_SELF", kind = "choice", roll = "greed", self = true, id = 1, item = 2 },
	{ key = "LOOT_ROLL_GREED", kind = "choice", roll = "greed", id = 1, player = 2, item = 3 },
}

-- Returns { kind, roll, historyID, player (nil = self), self, value, link } or nil.
function Parse.Roll(msg, G)
	G = G or _G
	if type(msg) ~= "string" then return nil end
	for _, spec in ipairs(Parse.ROLL_FORMATS) do
		local args = Parse.Match(G[spec.key], msg)
		if args then
			return {
				kind = spec.kind, roll = spec.roll, self = spec.self or false,
				historyID = tonumber(args[spec.id]),
				player = spec.player and Parse.ShortName(args[spec.player]) or nil,
				value = spec.value and tonumber(args[spec.value]) or nil,
				link = args[spec.item],
			}
		end
	end
	-- the announcement has no global string: "|HlootHistory:123|h[Loot]|h: <item link>"
	local id, rest = msg:match("^|HlootHistory:(%d+)|h%[.-%]|h:%s*(.*)$")
	if id and rest and rest:find("|Hitem:") and Parse.FirstItemLink(rest) == rest then
		return { kind = "start", historyID = tonumber(id), link = rest, self = false }
	end
	return nil
end

-------------------------------------------------------------------------------
-- Money (CHAT_MSG_MONEY): only the player's own share
-------------------------------------------------------------------------------

local function amount(fmt, text, default)
	local args = Parse.Match(fmt or default, text, false)
	return args and tonumber(args[1]) or 0
end

-- "13 Kupfer" / "1 Gold, 2 Silber, 3 Kupfer" -> copper
function Parse.MoneyText(text, G)
	G = G or _G
	if type(text) ~= "string" then return 0 end
	return amount(G.GOLD_AMOUNT, text, "%d Gold") * 10000
		+ amount(G.SILVER_AMOUNT, text, "%d Silver") * 100
		+ amount(G.COPPER_AMOUNT, text, "%d Copper")
end

function Parse.Money(msg, G)
	G = G or _G
	for _, key in ipairs({ "LOOT_MONEY_SPLIT", "YOU_LOOT_MONEY" }) do
		local args = Parse.Match(G[key], msg)
		if args and args[1] then
			local copper = Parse.MoneyText(args[1], G)
			if copper > 0 then return copper end
		end
	end
	return nil
end

-------------------------------------------------------------------------------
-- GUIDs
-------------------------------------------------------------------------------

-- "Creature-0-<server>-<instance>-<zoneUID>-<npcID>-<spawn>" -> npcID, instanceID, zoneUID
function Parse.CreatureGUID(guid)
	if type(guid) ~= "string" then return nil end
	local kind, _, _, instance, zone, npc = strsplit("-", guid)
	if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
	return tonumber(npc), tonumber(instance), zone
end

-------------------------------------------------------------------------------
-- Formatting
-------------------------------------------------------------------------------

-- seconds -> "42:17" (or "1:02:03")
function Parse.Clock(seconds)
	seconds = math.max(0, math.floor((seconds or 0) + 0.5))
	local h, m, s = math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60
	if h > 0 then return ("%d:%02d:%02d"):format(h, m, s) end
	return ("%d:%02d"):format(m, s)
end

-- seconds -> "m:ss" also past an hour ("66:12") - for narrow columns
function Parse.Minutes(seconds)
	seconds = math.max(0, math.floor((seconds or 0) + 0.5))
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:0:0:2:0|t"
-- copper -> "1[gold] 23[silver] 45[copper]" with the game's coin icons
function Parse.Coins(copper)
	copper = math.max(0, math.floor(copper or 0))
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local parts = {}
	if g > 0 then parts[#parts + 1] = g .. COIN:format("Gold") end
	if s > 0 or (g > 0 and c > 0) then parts[#parts + 1] = s .. COIN:format("Silver") end
	if c > 0 or #parts == 0 then parts[#parts + 1] = c .. COIN:format("Copper") end
	return table.concat(parts, " ")
end
