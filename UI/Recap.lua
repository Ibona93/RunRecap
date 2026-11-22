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
local WIDTH, HEIGHT = 680, 590
local INSET_W, LEFT_W, RIGHT_W, TOP = 408, 372, 242, 76
local PORTRAIT = "Interface\\Icons\\INV_Box_02"
local SKULL = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:12:12:0:0|t "
local frame, scroll, content
local pools = { boss = {}, item = {}, line = {} }
local used = { boss = 0, item = 0, line = 0 }
local facts = {}
local hovered            -- widget under the mouse (Shift changes its tooltip)

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

function Recap.BossTooltip(owner, run, entry)
	local l = L()
	local kill = entry.kill
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(kill.name or "?", W.GOLD[1], W.GOLD[2], W.GOLD[3])
	GameTooltip:AddLine(l.TT_KILL:format(ns.Parse.Clock(kill.at), kill.fight and ns.Parse.Clock(kill.fight) or "?"), 1, 1, 1)
	if shift() then
		GameTooltip:AddLine(l.TT_WIPES:format(run.bossWipes[kill.key] or 0), 1, 1, 1)
		local deaths = run.bossDeaths[kill.key]
		if deaths and #deaths > 0 then
			local names = {}
			for i, n in ipairs(deaths) do names[i] = playerName(run, n) end
			GameTooltip:AddLine(l.TT_DEATHS:format(table.concat(names, ", ")), 1, 1, 1, true)
		else
			GameTooltip:AddLine(l.TT_NO_DEATHS, W.GREY[1], W.GREY[2], W.GREY[3])
		end
		GameTooltip:AddLine(l.TT_ITEMS:format(entry.itemCount or 0), 1, 1, 1)
	end
	GameTooltip:Show()
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
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	local r, g, b = W.QualityColor(item.quality)
	GameTooltip:SetText(ns.Parse.ItemName(item.link) or "?", r, g, b)
	local winner = item.looter and item.rolls[item.looter]
	if item.rolling then
		GameTooltip:AddLine(l.ROLLING, W.GREY[1], W.GREY[2], W.GREY[3])
	elseif item.allPassed and not item.looter then
		GameTooltip:AddLine(l.ALL_PASSED, W.GREY[1], W.GREY[2], W.GREY[3])
	elseif item.historyID and item.looter then
		if winner and winner.choice then
			GameTooltip:AddLine(l.TT_WON_WITH:format(playerName(run, item.looter), choiceText(winner.choice, winner.value)), 1, 1, 1)
		else
			GameTooltip:AddLine(l.TT_WON:format(playerName(run, item.looter)), 1, 1, 1)
		end
	else
		GameTooltip:AddLine(l.DIRECT_LOOT, 1, 1, 1)
	end
	if shift() and item.historyID then
		local list = ns.Run.SortedRolls(item)
		if #list == 0 then
			GameTooltip:AddLine(l.TT_NO_ROLLS, W.GREY[1], W.GREY[2], W.GREY[3], true)
		else
			GameTooltip:AddLine(" ")
			for _, roll in ipairs(list) do
				GameTooltip:AddDoubleLine(playerName(run, roll.name), choiceText(roll.choice, roll.value), 1, 1, 1, 0.85, 0.85, 0.85)
			end
		end
	end
	GameTooltip:Show()
end

local function hover(widget, fn)
	widget:SetScript("OnEnter", function(self)
		hovered = self
		fn(self)
	end)
	widget:SetScript("OnLeave", function(self)
		if hovered == self then hovered = nil end
		GameTooltip:Hide()
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
		r.Minute:SetText(ns.Parse.Clock(kill.at))
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
	local i, y = 0, -34
	local function row(label, value, rgb, opts)
		i = i + 1
		local f = factRow(i)
		opts = opts or {}
		f.Label:SetFontObject(opts.header and ns.Fonts.Heading(13) or ns.Fonts.Text(12))
		f.Label:ClearAllPoints()
		f.Value:ClearAllPoints()
		f.Label:SetPoint("TOPLEFT", box, "TOPLEFT", 12, y)
		if opts.wide then
			f.Label:SetPoint("RIGHT", box, "RIGHT", -12, 0)
			f.Label:SetWordWrap(true)
		else
			f.Label:SetWidth(opts.header and (RIGHT_W - 24) or 150)
			f.Label:SetWordWrap(false)
		end
		f.Label:SetText(label)
		local lc = opts.header and W.GOLD or opts.labelColor or W.GOLD
		f.Label:SetTextColor(lc[1], lc[2], lc[3])
		f.Value:SetPoint("TOPRIGHT", box, "TOPRIGHT", -12, y)
		f.Value:SetText(value or "")
		local c = rgb or { 1, 1, 1 }
		f.Value:SetTextColor(c[1], c[2], c[3])
		f.Label:Show()
		f.Value:Show()
		y = y - math.max(f.Label:GetStringHeight() or 14, 14) - (opts.gap or 6)
	end

	row(l.FACT_DURATION, ns.Parse.Clock(s.duration))
	row(l.FACT_BOSSES, ("%d/%d"):format(s.done, s.total), s.done >= s.total and W.GREEN or W.YELLOW)
	row(l.FACT_WIPES, tostring(s.wipes), s.wipes == 0 and W.GREEN or W.YELLOW)
	row(l.FACT_GOLD, ns.Parse.Coins(s.money), nil, { gap = 14 })

	row(l.FACT_DEATHS, "", nil, { header = true })
	if #s.deaths == 0 and #s.noDeaths == 0 then
		row(l.NO_DEATHS, "", nil, { labelColor = W.GREY })
	end
	for _, d in ipairs(s.deaths) do
		row(playerName(run, d.name), tostring(d.n), d.n >= 3 and W.YELLOW or { 1, 1, 1 })
	end
	if #s.noDeaths > 0 then
		row(l.NO_DEATH_PLAYERS:format(table.concat(s.noDeaths, ", ")), "", nil, { wide = true, labelColor = W.GREY })
	end
	y = y - 8

	local highlights = {}
	if s.fastest then highlights[#highlights + 1] = { l.HL_FASTEST, s.fastest.name .. " (" .. ns.Parse.Clock(s.fastest.fight) .. ")" } end
	if s.mostLoot then highlights[#highlights + 1] = { l.HL_MOST_LOOT, playerName(run, s.mostLoot.name) .. " (" .. s.mostLoot.n .. ")" } end
	if s.mostDeaths then highlights[#highlights + 1] = { l.HL_MOST_DEATHS, playerName(run, s.mostDeaths.name) .. " (" .. s.mostDeaths.n .. ")" } end
	if #highlights > 0 then
		row(l.FACT_HIGHLIGHTS, "", nil, { header = true })
		for _, h in ipairs(highlights) do
			row(h[1], "", nil, { labelColor = W.GREY, gap = 1 })
			row("  " .. h[2], "", nil, { wide = true, labelColor = { 1, 1, 1 } })
		end
	end
	for j = i + 1, #facts do
		facts[j].Label:Hide()
		facts[j].Value:Hide()
	end
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

local function create()
	local l = L()
	frame = W.NativeWindow("RunRecapFrame", UIParent)
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
	-- the template's single inset is replaced by two (left: bosses, right: facts)
	for _, key in ipairs({ "Inset", "InsetBg" }) do
		local inset = W.Child(frame, key)
		if inset then inset:Hide() end
	end
	W.SetTitle(frame, l.RECAP_TITLE)
	local hasPortrait = W.SetPortrait(frame, PORTRAIT)

	local headerX = hasPortrait and 66 or 16
	frame.Dungeon = W.Text(frame, ns.Fonts.Heading(16), W.GOLD)
	frame.Dungeon:SetPoint("TOPLEFT", headerX, -30)
	frame.Dungeon:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
	frame.Dungeon:SetWordWrap(false)
	frame.Sub = W.Text(frame, ns.Fonts.Text(11), W.GREY)
	frame.Sub:SetPoint("TOPLEFT", frame.Dungeon, "BOTTOMLEFT", 0, -4)

	local left = W.Inset(frame)
	left:SetPoint("TOPLEFT", 10, -TOP)
	left:SetPoint("BOTTOMLEFT", 10, 28)
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

	frame.Facts = W.Inset(frame)
	frame.Facts:SetPoint("TOPLEFT", left, "TOPRIGHT", 6, 0)
	frame.Facts:SetPoint("BOTTOMRIGHT", -10, 28)
	frame.Facts.Header = W.Text(frame.Facts, ns.Fonts.Heading(13), W.GOLD)
	frame.Facts.Header:SetPoint("TOPLEFT", 12, -9)
	frame.Facts.Header:SetText(l.RUN_FACTS)

	frame.Hint = W.Text(frame, ns.Fonts.Text(11), W.GREEN)
	frame.Hint:SetPoint("BOTTOMLEFT", 16, 9)
	frame.Hint:SetText(l.SHIFT_HINT)

	frame.Close = W.Button(frame, l.CLOSE, 96, 22)
	frame.Close:SetPoint("BOTTOMRIGHT", -8, 4)
	frame.Close:SetScript("OnClick", function() Recap.Hide() end)
	frame.Options = W.Button(frame, l.OPTIONS, 96, 22)
	frame.Options:SetPoint("RIGHT", frame.Close, "LEFT", -2, 0)
	frame.Options:SetScript("OnClick", function() if ns.Options then ns.Options.Open() end end)

	frame:RegisterEvent("MODIFIER_STATE_CHANGED")
	frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	frame:SetScript("OnEvent", function(_, event)
		if event == "MODIFIER_STATE_CHANGED" then
			if hovered and hovered:IsShown() and hovered.Refresh then hovered.Refresh(hovered) end
		elseif frame:IsShown() then
			Recap.RequestRender()
		end
	end)
	frame:Hide()
	-- Blizzard's window sounds (character info open/close)
	frame:HookScript("OnShow", function() if PlaySound then pcall(PlaySound, 839) end end)
	frame:HookScript("OnHide", function()
		hovered = nil
		GameTooltip:Hide()
		if PlaySound then pcall(PlaySound, 840) end
	end)
	W.CloseOnEscape(frame, function() Recap.Hide() end)
end

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
	if not frame then create() end
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
