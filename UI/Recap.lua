local _, ns = ...

--[[
Recap window (Overview v2, native frame since 22.11.2026): Blizzard window template with a
chest portrait, left inset "Bosses & loot" (scrollable), right inset "Run facts".
Tooltips: boss row (Shift: wipes, deaths, item count), item name (Blizzard item tooltip +
looter/source), rest of the item row (rolls; Shift: all rolls). Updates live while the run
goes on (late rolls of the end boss).
]]

local Recap = {}
ns.Recap = Recap

local W = ns.Widgets
local WIDTH, HEIGHT = 680, 604
local INSET_W, LEFT_W, RIGHT_W, TOP = 408, 372, 242, 76
local PORTRAIT = ns.ICON
local SKULL = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:12:12:0:0|t "
-- one window per skin ("blizzard", "recap"); the locals below point to the active one
local windows = {}
local frame, scroll, content, pools, used, facts
local hovered            -- widget under the mouse (Shift changes its tooltip)
local HL_ICONS = {
	fastest = "Interface\\Icons\\INV_Misc_PocketWatch_01",
	hardest = "Interface\\Icons\\Ability_Warrior_ShieldBreak",
	loot = "Interface\\Icons\\INV_Box_02",
	deaths = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
	lucky = "Interface\\Icons\\INV_Misc_Coin_01",
	unlucky = "Interface\\Icons\\Spell_Shadow_GatherShadows",
}
-- bottom bar: buttons 10 px from the edge (as the boxes from the sides), 10 px below the boxes
local MARGIN, BUTTON_H = 10, 22
local BOTTOM = MARGIN + BUTTON_H + MARGIN
local RIGHT_H = HEIGHT - TOP - BOTTOM -- facts + gap + highlights
local HL_H = 30 + 4 * 37 + 6       -- highlights box: header + 4 compact rows

local function L() return ns.L end

-------------------------------------------------------------------------------
-- Tooltips
-------------------------------------------------------------------------------

local function shift() return IsShiftKeyDown and IsShiftKeyDown() end

local function playerName(run, name)
	if not name then return "?" end
	return W.ColorName(name, run.players and run.players[name] or nil)
end

local function choiceText(choice, value)
	local l = L()
	local text = l["ROLL_" .. tostring(choice):upper()] or tostring(choice)
	if value then text = text .. " " .. value end
	return text
end

local function sourceText(run, item)
	local l = L()
	if type(item.source) == "number" then
		local kill = run.kills[item.source]
		local name = kill and kill.name or "?"
		return item.sure and l.TT_SOURCE:format(name) or l.TT_SOURCE_PROBABLY:format(name)
	end
	return l.TT_SOURCE:format(l.TRASH)
end

-- Our own tooltip for boss and roll details: opaque, so the window text behind it doesn't show
-- through (Felix, 24.11.2026). The item tooltip stays Blizzard's GameTooltip (item compare,
-- other addons' lines). Our frame, not Blizzard's: changing its background is taint-free.
local TIP_BG = { 0.06, 0.05, 0.04, 1 }
local tipFrame
local function Tip()
	if not tipFrame then
		tipFrame = CreateFrame("GameTooltip", "RunRecapTooltip", UIParent, "GameTooltipTemplate")
		local function opaque(self)
			if self.NineSlice and self.NineSlice.SetCenterColor then
				self.NineSlice:SetCenterColor(TIP_BG[1], TIP_BG[2], TIP_BG[3], TIP_BG[4])
			elseif self.SetBackdropColor then
				pcall(self.SetBackdropColor, self, TIP_BG[1], TIP_BG[2], TIP_BG[3], TIP_BG[4])
			end
		end
		tipFrame:HookScript("OnShow", opaque)
		tipFrame:HookScript("OnSizeChanged", opaque)
	end
	return tipFrame
end
Recap.Tip = Tip

local function hideTips()
	GameTooltip:Hide()
	if tipFrame then tipFrame:Hide() end
end

function Recap.BossTooltip(owner, run, entry)
	local l = L()
	local kill = entry.kill
	local tt = Tip()
	tt:SetOwner(owner, "ANCHOR_RIGHT")
	tt:SetText(kill.name or "?", W.GOLD[1], W.GOLD[2], W.GOLD[3])
	tt:AddLine(l.TT_KILL:format(ns.Parse.Clock(kill.at), kill.fight and ns.Parse.Clock(kill.fight) or "?"), 1, 1, 1)
	if shift() then
		tt:AddLine(l.TT_WIPES:format(run.bossWipes[kill.key] or 0), 1, 1, 1)
		local deaths = run.bossDeaths[kill.key]
		if deaths and #deaths > 0 then
			local names = {}
			for i, n in ipairs(deaths) do names[i] = playerName(run, n) end
			tt:AddLine(l.TT_DEATHS:format(table.concat(names, ", ")), 1, 1, 1, true)
		else
			tt:AddLine(l.TT_NO_DEATHS, W.GREY[1], W.GREY[2], W.GREY[3])
		end
		tt:AddLine(l.TT_ITEMS:format(entry.itemCount or 0), 1, 1, 1)
	end
	tt:Show()
end

function Recap.ItemTooltip(owner, run, item)
	local l = L()
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, item.link)
	if not ok then GameTooltip:SetText(ns.Parse.ItemName(item.link) or "?") end
	GameTooltip:AddLine(" ")
	if item.looter then
		GameTooltip:AddLine(l.TT_LOOTED_BY:format(item.looter), W.GOLD[1], W.GOLD[2], W.GOLD[3])
	elseif item.rolling then
		GameTooltip:AddLine(l.ROLLING, W.GREY[1], W.GREY[2], W.GREY[3])
	end
	GameTooltip:AddLine(sourceText(run, item), W.GREY[1], W.GREY[2], W.GREY[3])
	if not item.sure then
		GameTooltip:AddLine(l.TT_UNSURE_WHY, W.DARKGREY[1], W.DARKGREY[2], W.DARKGREY[3], true)
	end
	GameTooltip:Show()
end

function Recap.RollTooltip(owner, run, item)
	local l = L()
	local tt = Tip()
	tt:SetOwner(owner, "ANCHOR_RIGHT")
	local r, g, b = W.QualityColor(item.quality)
	tt:SetText(ns.Parse.ItemName(item.link) or "?", r, g, b)
	local winner = item.looter and item.rolls[item.looter]
	if item.rolling then
		tt:AddLine(l.ROLLING, W.GREY[1], W.GREY[2], W.GREY[3])
	elseif item.allPassed and not item.looter then
		tt:AddLine(l.ALL_PASSED, W.GREY[1], W.GREY[2], W.GREY[3])
	elseif item.historyID and item.looter then
		if winner and winner.choice then
			tt:AddLine(l.TT_WON_WITH:format(playerName(run, item.looter), choiceText(winner.choice, winner.value)), 1, 1, 1)
		else
			tt:AddLine(l.TT_WON:format(playerName(run, item.looter)), 1, 1, 1)
		end
	else
		tt:AddLine(l.DIRECT_LOOT, 1, 1, 1)
	end
	if shift() and item.historyID then
		local list = ns.Run.SortedRolls(item)
		if #list == 0 then
			tt:AddLine(l.TT_NO_ROLLS, W.GREY[1], W.GREY[2], W.GREY[3], true)
		else
			tt:AddLine(" ")
			for _, roll in ipairs(list) do
				tt:AddDoubleLine(playerName(run, roll.name), choiceText(roll.choice, roll.value), 1, 1, 1, 0.85, 0.85, 0.85)
			end
		end
	end
	tt:Show()
end

local function hover(widget, fn)
	widget:SetScript("OnEnter", function(self)
		hovered = self
		fn(self)
	end)
	widget:SetScript("OnLeave", function(self)
		if hovered == self then hovered = nil end
		hideTips()
	end)
	widget.Refresh = fn
end

-------------------------------------------------------------------------------
-- Rows (pooled)
-------------------------------------------------------------------------------

local function newBossRow()
	local r = CreateFrame("Button", nil, content)
	r:SetHeight(22)
	r.Minute = W.Text(r, ns.Fonts.Text(11), W.GREY)
	r.Minute:SetPoint("LEFT", 0, 0)
	r.Minute:SetWidth(38)
	r.Name = W.Text(r, ns.Fonts.Heading(14), { 1, 1, 1 })
	r.Name:SetPoint("LEFT", 42, 0)
	r.Name:SetWordWrap(false)
	r.Tag = CreateFrame("Frame", nil, r)
	r.Tag.Text = W.Text(r.Tag, ns.Fonts.Text(11), W.GOLD)
	r.Tag.Text:SetPoint("LEFT", 0, 0)
	r.Tag:SetHeight(15)
	r.Tag:SetPoint("LEFT", r.Name, "RIGHT", 8, 0)
	r.Fight = W.Text(r, ns.Fonts.Text(11), W.GREY)
	r.Fight:SetPoint("RIGHT", -4, 0)
	r.Fight:SetJustifyH("RIGHT")
	hover(r, function(self)
		if self.entry then Recap.BossTooltip(self, frame.run, self.entry) end
	end)
	return r
end

local function newItemRow()
	local r = CreateFrame("Frame", nil, content)
	r:SetHeight(19)
	r:EnableMouse(true)
	r.Border = r:CreateTexture(nil, "ARTWORK", nil, 1)
	r.Border:SetSize(16, 16)
	r.Border:SetPoint("LEFT", 42, 0)
	r.Icon = r:CreateTexture(nil, "ARTWORK", nil, 2)
	r.Icon:SetSize(14, 14)
	r.Icon:SetPoint("CENTER", r.Border, "CENTER")
	r.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	r.Player = W.Text(r, ns.Fonts.Text(12))
	r.Player:SetPoint("RIGHT", -4, 0)
	r.Player:SetJustifyH("RIGHT")
	r.NameButton = CreateFrame("Button", nil, r)
	r.NameButton:SetHeight(17)
	r.NameButton:SetPoint("LEFT", r.Border, "RIGHT", 5, 0)
	r.Name = W.Text(r.NameButton, ns.Fonts.Text(12))
	r.Name:SetPoint("LEFT")
	r.Name:SetWordWrap(false)
	r.NameButton:SetScript("OnClick", function(self)
		-- Shift-click links the item in chat, like everywhere in the game
		local item = self:GetParent().item
		if item and IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(item.link) end
	end)
	hover(r.NameButton, function(self)
		local item = self:GetParent().item
		if item then Recap.ItemTooltip(self, frame.run, item) end
	end)
	hover(r, function(self)
		if self.item then Recap.RollTooltip(self, frame.run, self.item) end
	end)
	return r
end

local function newLineRow()
	local r = CreateFrame("Frame", nil, content)
	r:SetHeight(17)
	r.Text = W.Text(r, ns.Fonts.Text(11), W.GREY)
	r.Text:SetPoint("LEFT", 42, 0)
	r.Text:SetPoint("RIGHT", -4, 0)
	return r
end

local makers = { boss = newBossRow, item = newItemRow, line = newLineRow }

local function take(kind)
	used[kind] = used[kind] + 1
	local r = pools[kind][used[kind]]
	if not r then
		r = makers[kind]()
		pools[kind][used[kind]] = r
	end
	r:Show()
	return r
end

local function place(r, y, height)
	r:ClearAllPoints()
	r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
	r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
	return y + (height or r:GetHeight())
end

local function itemIcon(itemID)
	local icon
	if itemID and C_Item and C_Item.GetItemIconByID then icon = ns.TryCall(C_Item.GetItemIconByID, itemID) end
	if not icon and itemID and GetItemIcon then icon = ns.TryCall(GetItemIcon, itemID) end
	return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function fillItem(r, run, item)
	r.item = item
	local qr, qg, qb = W.QualityColor(item.quality)
	r.Border:SetColorTexture(qr, qg, qb, 0.9)
	r.Icon:SetTexture(itemIcon(item.itemID))
	local name = "[" .. (ns.Parse.ItemName(item.link) or "?") .. "]"
	if (item.count or 1) > 1 then name = name .. " x" .. item.count end
	r.Name:SetText("|c" .. W.QualityHex(item.quality) .. name .. "|r")
	if item.looter then
		r.Player:SetText(playerName(run, item.looter))
	elseif item.rolling then
		r.Player:SetText(W.Colored(L().ROLLING, W.GREY))
	elseif item.allPassed then
		r.Player:SetText(W.Colored(L().ALL_PASSED, W.GREY))
	else
		r.Player:SetText("")
	end
	local maxName = LEFT_W - 70 - (r.Player:GetStringWidth() or 60) - 12
	r.Name:SetWidth(math.max(60, math.min(maxName, (r.Name:GetStringWidth() or 100) + 2)))
	r.NameButton:SetWidth(r.Name:GetWidth())
end

local function fillBoss(r, run, entry, label)
	local l = L()
	r.entry = entry
	if entry then
		local kill = entry.kill
		r.Minute:SetText(ns.Parse.Minutes(kill.at))
		r.Name:SetText(kill.name or "?")
		r.Name:SetTextColor(1, 1, 1)
		r.Fight:SetText(kill.fight and l.FIGHT:format(ns.Parse.Clock(kill.fight)) or "")
		local final = ns.Run.IsFinal(kill)
		r.Tag:SetShown(final)
		if final then
			r.Tag.Text:SetText(SKULL .. l.FINAL_BOSS)
			r.Tag:SetWidth(math.ceil(r.Tag.Text:GetStringWidth() or 50) + 4)
		end
		r:EnableMouse(true)
	else
		r.Minute:SetText("")
		r.Name:SetText(label)
		r.Name:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
		r.Fight:SetText("")
		r.Tag:Hide()
		r:EnableMouse(false)
	end
	local maxName = LEFT_W - 42 - (r.Fight:GetStringWidth() or 0) - (r.Tag:IsShown() and r.Tag:GetWidth() + 16 or 8)
	r.Name:SetWidth(math.max(60, math.min(maxName, (r.Name:GetStringWidth() or 100) + 2)))
end

-------------------------------------------------------------------------------
-- Facts (right column)
-------------------------------------------------------------------------------

local function factRow(i)
	local f = facts[i]
	if f then return f end
	local box = frame.Facts
	f = {}
	f.Label = W.Text(box, ns.Fonts.Text(12), { 1, 1, 1 })
	f.Value = W.Text(box, ns.Fonts.Text(12), { 1, 1, 1 })
	f.Value:SetJustifyH("RIGHT")
	facts[i] = f
	return f
end

local function renderFacts(run, s)
	local l = L()
	local box = frame.Facts
	local i, y = 0, -32
	local function row(label, value, rgb, opts)
		i = i + 1
		local f = factRow(i)
		opts = opts or {}
		f.Label:SetFontObject(ns.Fonts.Text(12))
		f.Value:SetFontObject(ns.Fonts.Text(12))
		f.Label:ClearAllPoints()
		f.Value:ClearAllPoints()
		f.Label:SetPoint("TOPLEFT", box, "TOPLEFT", 12, y)
		if opts.wide then
			f.Label:SetPoint("RIGHT", box, "RIGHT", -12, 0)
			f.Label:SetWordWrap(true)
		else
			f.Label:SetWidth(RIGHT_W - 70)
			f.Label:SetWordWrap(false)
		end
		f.Label:SetText(label)
		local lc = opts.labelColor or W.GOLD
		f.Label:SetTextColor(lc[1], lc[2], lc[3])
		f.Value:SetPoint("TOPRIGHT", box, "TOPRIGHT", -12, y)
		f.Value:SetText(value or "")
		local c = rgb or { 1, 1, 1 }
		f.Value:SetTextColor(c[1], c[2], c[3])
		f.Label:Show()
		f.Value:Show()
		y = y - math.max(f.Label:GetStringHeight() or 14, 14) - (opts.gap or 6)
	end

	local function separator(line)
		y = y - 3
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", box, "TOPLEFT", 10, y)
		line:SetPoint("TOPRIGHT", box, "TOPRIGHT", -10, y)
		y = y - 8
	end
	local coins = ns.Parse.Coins

	row(l.FACT_DURATION, ns.Parse.Clock(s.duration), nil, { gap = 4 })
	row(l.FACT_BOSSES, ("%d/%d"):format(s.done, s.total), s.done >= s.total and W.GREEN or W.YELLOW, { gap = 4 })
	row(l.FACT_WIPES, tostring(s.wipes), s.wipes == 0 and W.GREEN or W.YELLOW, { gap = 4 })

	-- money: own looted gold + vendor value of own loot - repair costs = balance
	separator(box.Separator)
	row(l.FACT_GOLD, "+ " .. coins(s.money), nil, { gap = 4 })
	row(l.FACT_VENDOR, "+ " .. coins(s.vendor), nil, { gap = 4 })
	row(l.FACT_REPAIR, (s.repair > 0 and "– " or "") .. coins(s.repair), nil, { gap = 4 })
	row(l.FACT_BALANCE, (s.balance < 0 and "– " or "") .. coins(math.abs(s.balance)),
		s.balance > 0 and W.GREEN or s.balance < 0 and W.RED or { 1, 1, 1 }, { gap = 4 })

	-- deaths
	separator(box.Separator2)
	row(l.FACT_DEATHS, "")
	if #s.deaths == 0 and #s.noDeaths == 0 then
		row(l.NO_DEATHS, "", nil, { labelColor = W.GREY })
	end
	for _, d in ipairs(s.deaths) do
		row(playerName(run, d.name), tostring(d.n), d.n >= 3 and W.YELLOW or { 1, 1, 1 }, { labelColor = { 1, 1, 1 }, gap = 4 })
	end
	-- players without a death: one row each, "0" in green (Felix, 22.11.2026)
	for _, name in ipairs(s.noDeaths) do
		row(playerName(run, name), "0", W.GREEN, { labelColor = { 1, 1, 1 }, gap = 4 })
	end
	for j = i + 1, #facts do
		facts[j].Label:Hide()
		facts[j].Value:Hide()
	end

	-- the facts box is as tall as its content; the highlights box gets the rest
	local factsH = math.min(RIGHT_H - 170, math.max(RIGHT_H - HL_H - 6, -y + 4))
	box:SetHeight(factsH)
	local hl = frame.Highlights
	hl:SetHeight(RIGHT_H - factsH - 6)
	Recap.RenderHighlights(run, s, RIGHT_H - factsH - 6)
end

-- Text for one highlight entry (Run.Highlights): label line (with the number, it is short),
-- name line (long names get the full width), icon.
function Recap.HighlightText(run, h)
	local l = L()
	local clock = ns.Parse.Clock
	local function lbl(text, value) return text .. "  |cffffffff" .. value .. "|r" end
	if h.key == "fastest" then
		return lbl(l.HL_FASTEST, clock(h.value)), h.name or "?", HL_ICONS.fastest
	elseif h.key == "hardest" then
		local v = h.wipes and ns.WipesText(h.wipes) or clock(h.value)
		return lbl(l.HL_HARDEST, v), h.name or "?", HL_ICONS.hardest
	elseif h.key == "loot" then
		return lbl(l.HL_MOST_LOOT, h.value), playerName(run, h.name), HL_ICONS.loot
	elseif h.key == "deaths" then
		return lbl(l.HL_MOST_DEATHS, h.value), playerName(run, h.name), HL_ICONS.deaths
	elseif h.key == "lucky" then
		return lbl(l.HL_LUCKY, choiceText(h.choice, h.value)), playerName(run, h.name), HL_ICONS.lucky
	elseif h.key == "unlucky" then
		return lbl(l.HL_UNLUCKY, h.value .. "× " .. l.ROLL_NEED), playerName(run, h.name), HL_ICONS.unlucky
	elseif h.key == "item" then
		local item = h.item
		local name = "|c" .. W.QualityHex(item.quality) .. "[" .. (ns.Parse.ItemName(item.link) or "?") .. "]|r"
		return item.looter and lbl(l.HL_BEST_ITEM, playerName(run, item.looter)) or l.HL_BEST_ITEM, name,
			itemIcon(item.itemID)
	end
	return "?", "", nil
end

-- Up to four compact rows, spread over the box.
function Recap.RenderHighlights(run, s, boxH)
	local hl = frame.Highlights
	local list = s.highlights or {}
	local step = math.max(34, math.min(40, ((boxH or HL_H) - 34) / 4))
	for k, tile in ipairs(hl.Tiles) do
		local h = list[k]
		tile:SetShown(h ~= nil)
		tile:ClearAllPoints()
		tile:SetPoint("TOPLEFT", hl, "TOPLEFT", 8, -30 - (k - 1) * step)
		tile:SetPoint("RIGHT", hl, "RIGHT", -8, 0)
		tile:SetHeight(step - 4)
		if h then
			local label, value, icon = Recap.HighlightText(run, h)
			tile.Icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			tile.Label:SetText(label)
			tile.Value:SetText(value)
			tile.key = h.key
		end
	end
	hl.Empty:SetShown(#list == 0)
end

-------------------------------------------------------------------------------
-- Render
-------------------------------------------------------------------------------

function Recap.Render()
	if not frame or not frame.run then return end
	local run, l = frame.run, L()
	local showGreen = ns.db and ns.db.showGreen
	local s = ns.Run.Summary(run, showGreen)
	for kind in pairs(used) do
		for i = 1, #pools[kind] do pools[kind][i]:Hide() end
		used[kind] = 0
	end

	frame.Dungeon:SetText(run.name or "")
	local when = date and run.date and date(l.DATE_FORMAT, run.date) or ""
	local state = run.completed and l.COMPLETED or l.IN_PROGRESS
	frame.Sub:SetText(("%s · %s%s"):format(state, ns.Parse.Clock(s.duration), when ~= "" and (" · " .. when) or ""))

	local y = 0
	for _, entry in ipairs(s.bosses) do
		local r = take("boss")
		fillBoss(r, run, entry)
		y = place(r, y)
		for _, item in ipairs(entry.sure) do
			local ir = take("item")
			fillItem(ir, run, item)
			y = place(ir, y)
		end
		if #entry.unsure > 0 then
			local lr = take("line")
			lr.Text:SetText(l.PROBABLY_HEADER)
			y = place(lr, y)
			for _, item in ipairs(entry.unsure) do
				local ir = take("item")
				fillItem(ir, run, item)
				y = place(ir, y)
			end
		end
		if #entry.sure + #entry.unsure == 0 then
			local lr = take("line")
			lr.Text:SetText(showGreen and l.NO_LOOT_GREEN or l.NO_LOOT_BLUE)
			y = place(lr, y)
		end
		y = y + 6
	end
	if #s.trash > 0 then
		local r = take("boss")
		fillBoss(r, run, nil, l.TRASH)
		y = place(r, y)
		for _, item in ipairs(s.trash) do
			local ir = take("item")
			fillItem(ir, run, item)
			y = place(ir, y)
		end
		y = y + 6
	end
	if #s.bosses == 0 and #s.trash == 0 then
		local lr = take("line")
		lr.Text:SetText(l.NO_BOSSES)
		y = place(lr, y)
	end
	if s.hidden > 0 then
		local lr = take("line")
		lr.Text:SetText(l.HIDDEN_GREEN:format(s.hidden))
		y = place(lr, y + 4)
	end
	content:SetHeight(math.max(y, 10))
	renderFacts(run, s)
	if hovered and hovered:IsShown() and hovered.Refresh then hovered.Refresh(hovered) end
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

local function savePosition()
	if not ns.db or not frame then return end
	local point, _, relPoint, x, y = frame:GetPoint()
	ns.db.window = { point = point, relPoint = relPoint, x = x, y = y }
end

-- A highlight row: icon, grey label above, white value below (compact, no background).
local function newTile(parent, index)
	local t = CreateFrame("Frame", nil, parent)
	t:SetHeight(42)
	t:SetPoint("TOPLEFT", 8, -30 - (index - 1) * 46)
	t:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
	t.Icon = t:CreateTexture(nil, "ARTWORK")
	t.Icon:SetSize(30, 30)
	t.Icon:SetPoint("LEFT", 4, 0)
	t.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	t.Label = W.Text(t, ns.Fonts.Text(11), W.GREY)
	t.Label:SetPoint("BOTTOMLEFT", t.Icon, "RIGHT", 8, 1)
	t.Label:SetPoint("RIGHT", t, "RIGHT", -6, 0)
	t.Label:SetWordWrap(false)
	t.Value = W.Text(t, ns.Fonts.Text(12), { 1, 1, 1 })
	t.Value:SetPoint("TOPLEFT", t.Icon, "RIGHT", 8, -2)
	t.Value:SetPoint("RIGHT", t, "RIGHT", -6, 0)
	t.Value:SetWordWrap(false)
	return t
end

local function create(skin)
	local l = L()
	local native = skin ~= "recap"
	frame = W.SkinWindow(native and "RunRecapFrame" or "RunRecapFrameDark", skin)
	frame.skin = skin
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePosition()
	end)
	local hasPortrait = false
	if native then
		-- the template's single inset is replaced by our own boxes
		for _, key in ipairs({ "Inset", "InsetBg" }) do
			local inset = W.Child(frame, key)
			if inset then inset:Hide() end
		end
		W.SetTitle(frame, l.RECAP_TITLE)
		hasPortrait = W.SetPortrait(frame, PORTRAIT)
	else
		frame.Title = W.Text(frame, ns.Fonts.Heading(20), W.GOLD)
		frame.Title:SetPoint("TOPLEFT", 16, -10)
		frame.Title:SetText(l.RECAP_TITLE)
	end

	frame.Dungeon = W.Text(frame, ns.Fonts.Heading(16), native and W.GOLD or { 1, 1, 1 })
	if native then
		frame.Dungeon:SetPoint("TOPLEFT", hasPortrait and 66 or 16, -30)
	else
		frame.Dungeon:SetPoint("TOPLEFT", frame.Title, "BOTTOMLEFT", 0, -2)
	end
	frame.Dungeon:SetPoint("RIGHT", frame, "RIGHT", -40, 0)
	frame.Dungeon:SetWordWrap(false)
	frame.Sub = W.Text(frame, ns.Fonts.Text(11), W.GREY)
	frame.Sub:SetPoint("TOPLEFT", frame.Dungeon, "BOTTOMLEFT", 0, -3)

	local left = W.SkinInset(frame, skin)
	left:SetPoint("TOPLEFT", 10, -TOP)
	left:SetPoint("BOTTOMLEFT", MARGIN, BOTTOM)
	left:SetWidth(INSET_W)
	frame.Left = left
	frame.LeftHeader = W.Text(left, ns.Fonts.Heading(13), W.GOLD)
	frame.LeftHeader:SetPoint("TOPLEFT", 10, -9)
	frame.LeftHeader:SetText(l.BOSSES_LOOT)

	scroll = W.Scroll(left)
	scroll:SetPoint("TOPLEFT", 8, -30)
	scroll:SetPoint("BOTTOMRIGHT", -28, 6)
	content = scroll.Content
	content:SetWidth(LEFT_W)

	frame.Highlights = W.SkinInset(frame, skin)
	frame.Highlights:SetPoint("BOTTOMRIGHT", -MARGIN, BOTTOM)
	frame.Highlights:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 6, 0)
	frame.Highlights:SetHeight(RIGHT_H - 300 - 6)
	frame.Highlights.Header = W.Text(frame.Highlights, ns.Fonts.Heading(13), W.GOLD)
	frame.Highlights.Header:SetPoint("TOPLEFT", 12, -9)
	frame.Highlights.Header:SetText(l.FACT_HIGHLIGHTS)
	frame.Highlights.Tiles = {}
	for k = 1, 4 do frame.Highlights.Tiles[k] = newTile(frame.Highlights, k) end
	frame.Highlights.Empty = W.Text(frame.Highlights, ns.Fonts.Text(11), W.GREY)
	frame.Highlights.Empty:SetPoint("TOPLEFT", 12, -32)
	frame.Highlights.Empty:SetText(l.NO_HIGHLIGHTS)

	frame.Facts = W.SkinInset(frame, skin)
	frame.Facts:SetPoint("TOPLEFT", left, "TOPRIGHT", 6, 0)
	frame.Facts:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -TOP)
	frame.Facts:SetHeight(300)
	frame.Facts.Header = W.Text(frame.Facts, ns.Fonts.Heading(13), W.GOLD)
	frame.Facts.Header:SetPoint("TOPLEFT", 12, -9)
	frame.Facts.Header:SetText(l.RUN_FACTS)
	frame.Facts.Separator = W.Separator(frame.Facts, skin)
	frame.Facts.Separator2 = W.Separator(frame.Facts, skin)

	frame.Hint = W.Text(frame, ns.Fonts.Text(11), W.GREEN)
	frame.Hint:SetPoint("LEFT", frame, "BOTTOMLEFT", 16, MARGIN + BUTTON_H / 2)
	frame.Hint:SetText(l.SHIFT_HINT)

	frame.Close = W.SkinButton(frame, l.CLOSE, 96, BUTTON_H, skin)
	frame.Close:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN)
	frame.Close:SetScript("OnClick", function() Recap.Hide() end)
	frame.Options = W.SkinButton(frame, l.OPTIONS, 96, BUTTON_H, skin)
	frame.Options:SetPoint("RIGHT", frame.Close, "LEFT", native and -2 or -6, 0)
	frame.Options:SetScript("OnClick", function() if ns.Options then ns.Options.Open() end end)

	local own = frame
	frame:RegisterEvent("MODIFIER_STATE_CHANGED")
	frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	frame:SetScript("OnEvent", function(_, event)
		if own ~= frame then return end
		if event == "MODIFIER_STATE_CHANGED" then
			if hovered and hovered:IsShown() and hovered.Refresh then hovered.Refresh(hovered) end
		elseif own:IsShown() then
			Recap.RequestRender()
		end
	end)
	frame:Hide()
	-- Blizzard's window sounds (character info open/close)
	frame:HookScript("OnShow", function() if PlaySound then pcall(PlaySound, 839) end end)
	frame:HookScript("OnHide", function()
		hovered = nil
		hideTips()
		if PlaySound then pcall(PlaySound, 840) end
	end)
	W.CloseOnEscape(frame, function() Recap.Hide() end)
	pools = { boss = {}, item = {}, line = {} }
	used = { boss = 0, item = 0, line = 0 }
	facts = {}
	windows[skin] = { frame = frame, scroll = scroll, content = content, pools = pools, used = used, facts = facts }
end

-- Makes the window of `skin` the active one (built on first use).
local function useSkin(skin)
	skin = skin == "recap" and "recap" or "blizzard"
	local w = windows[skin]
	if not w then
		create(skin)
		return
	end
	frame, scroll, content, pools, used, facts = w.frame, w.scroll, w.content, w.pools, w.used, w.facts
end

local function currentSkin() return ns.db and ns.db.skin or "blizzard" end

local function applyPosition()
	frame:ClearAllPoints()
	local p = ns.db and ns.db.window
	if p and p.point then
		frame:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	end
end

function Recap.Show(run)
	if not run then return end
	if not frame or frame.skin ~= currentSkin() then
		local old = frame
		useSkin(currentSkin())
		if old and old ~= frame and old:IsShown() then old:Hide() end
	end
	if not frame:IsShown() then applyPosition() end
	frame.run = run
	frame:Show()
	if frame.Raise then frame:Raise() end
	scroll:SetVerticalScroll(0)
	Recap.Render()
	return frame
end

function Recap.Hide()
	if frame then frame:Hide() end
end

function Recap.Toggle(run)
	if frame and frame:IsShown() and frame.run == run then Recap.Hide() else Recap.Show(run) end
end

function Recap.IsShown() return frame and frame:IsShown() or false end
function Recap.Frame() return frame end

-- Shown fact rows as "label|value" (tests).
function Recap.FactLines()
	local out = {}
	for _, f in ipairs(facts or {}) do
		if f.Label:IsShown() then out[#out + 1] = tostring(f.Label:GetText()) .. "|" .. tostring(f.Value:GetText()) end
	end
	return out
end

-- Skin changed in the options: show the open recap in the new skin.
function Recap.ApplySkin()
	if not frame or frame.skin == currentSkin() then return end
	local wasShown, run = frame:IsShown(), frame.run
	if wasShown then frame:Hide() end
	useSkin(currentSkin())
	if wasShown and run then Recap.Show(run) end
end

local renderPending = false
function Recap.RequestRender()
	if renderPending then return end
	renderPending = true
	local function go()
		renderPending = false
		if frame and frame:IsShown() then Recap.Render() end
	end
	if C_Timer and C_Timer.After then C_Timer.After(0.25, go) else go() end
end

-- Run changed (Run.onChange): refresh if this run is on screen.
function Recap.OnRunChanged(run)
	if frame and frame:IsShown() and frame.run == run then Recap.RequestRender() end
end
