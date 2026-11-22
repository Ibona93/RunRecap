local _, ns = ...

--[[
Introduction tour (as in BGF): a small window with five pages (it runs by itself, loot, tooltips,
facts & highlights, options). Shown once at login instead of "What's new" when
RunRecapDB.tourSeen is missing. Restart from the options or with /recap tour.
No page for the success banner - only a visual effect (Felix, 22.11.2026).

The pictures are built from plain frames, textures and font strings in the look of the recap
window. Texts: Data/Tour.lua (German or English). Look as in BGF: dark brown, golden border.
]]

local Tour = {}
ns.Tour = Tour

local WIDTH, HEIGHT, PAD = 560, 420, 22
local BOX_Y, BOX_W, BOX_H = -64, 516, 170
local GOLD = { 1, 0.82, 0 }
local TEXT = { 0.92, 0.9, 0.86 }
local GREY = { 0.62, 0.62, 0.62 }
local GREEN = { 0.47, 0.82, 0.47 }
local QUALITY = { [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 } }
local SKULL = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:12:12:0:0|t "

local frame
local pictures = {}
Tour.pictures = pictures

-------------------------------------------------------------------------------
-- Small drawing helpers for the pictures
-------------------------------------------------------------------------------

local function fs(parent, template, color, x, y, text)
	local s = parent:CreateFontString(nil, "ARTWORK", template)
	s:SetJustifyH("LEFT")
	if color then s:SetTextColor(color[1], color[2], color[3]) end
	if x then s:SetPoint("TOPLEFT", x, y) end
	if text then s:SetText(text) end
	return s
end

local function rfs(parent, template, color, x, y, text)
	local s = parent:CreateFontString(nil, "ARTWORK", template)
	s:SetJustifyH("RIGHT")
	if color then s:SetTextColor(color[1], color[2], color[3]) end
	s:SetPoint("TOPRIGHT", x, y)
	if text then s:SetText(text) end
	return s
end

local function box(parent, x, y, w, h, bg, border)
	local b = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	b:SetPoint("TOPLEFT", x, y)
	b:SetSize(w, h)
	if b.SetBackdrop then
		b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
		b:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
		b:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
	end
	return b
end

local function icon(parent, x, y, size, texture)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetTexture(texture)
	t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	t:SetSize(size, size)
	t:SetPoint("TOPLEFT", x, y)
	return t
end

local function name(n, class) return ns.Widgets.ColorName(n, class) end

-- An item row like in the recap window: small icon with quality border, [name], looter.
local function itemRow(parent, x, y, w, item)
	local q = QUALITY[item[2]] or QUALITY[3]
	local border = parent:CreateTexture(nil, "ARTWORK", nil, 1)
	border:SetColorTexture(q[1], q[2], q[3], 0.9)
	border:SetSize(14, 14)
	border:SetPoint("TOPLEFT", x, y - 1)
	local ic = parent:CreateTexture(nil, "ARTWORK", nil, 2)
	ic:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	ic:SetSize(12, 12)
	ic:SetPoint("CENTER", border, "CENTER")
	fs(parent, "GameFontHighlightSmall", q, x + 19, y, "[" .. item[1] .. "]")
	rfs(parent, "GameFontHighlightSmall", nil, -(BOX_W - x - w), y, name(item[3], item[4]))
end

-------------------------------------------------------------------------------
-- The five pictures (each one built once, on first use)
-------------------------------------------------------------------------------

local DRAW = {}

function DRAW.bosses(p, s)
	fs(p, "GameFontNormal", GOLD, 24, -14, s.header)
	for i, row in ipairs(s.rows) do
		local y = -40 - (i - 1) * 40
		fs(p, "GameFontDisableSmall", GREY, 24, y - 2, row[1])
		local n = fs(p, "GameFontHighlight", { 1, 1, 1 }, 74, y, row[2])
		if row[4] then
			local tag = fs(p, "GameFontNormalSmall", GOLD, nil, nil, SKULL .. s.final)
			tag:SetPoint("LEFT", n, "RIGHT", 8, 0)
		end
		rfs(p, "GameFontDisableSmall", GREY, -24, y - 2, s.fight:format(row[3]))
	end
end

function DRAW.loot(p, s)
	fs(p, "GameFontDisableSmall", GREY, 24, -14, "42:17")
	local n = fs(p, "GameFontHighlight", { 1, 1, 1 }, 74, -12, s.boss)
	local tag = fs(p, "GameFontNormalSmall", GOLD, nil, nil, SKULL)
	tag:SetPoint("LEFT", n, "RIGHT", 6, 0)
	itemRow(p, 74, -34, 420, s.items[1])
	itemRow(p, 74, -52, 420, s.items[2])
	fs(p, "GameFontDisableSmall", GREY, 74, -74, s.probably)
	itemRow(p, 74, -92, 420, s.unsure)
	fs(p, "GameFontNormal", GOLD, 74, -118, s.trash)
	itemRow(p, 74, -140, 420, s.trashItem)
end

function DRAW.tooltip(p, s)
	local key = box(p, 24, -60, 78, 36, { 0.24, 0.2, 0.15 }, { 0.6, 0.48, 0.25 })
	local k = fs(key, "GameFontNormal", GOLD)
	k:SetPoint("CENTER")
	k:SetText("Shift")
	local tip = box(p, 130, -10, 300, 150, { 0.04, 0.04, 0.09, 0.95 }, { 0.47, 0.47, 0.55 })
	fs(tip, "GameFontHighlight", QUALITY[3], 12, -10, s.item)
	fs(tip, "GameFontHighlightSmall", { 1, 1, 1 }, 12, -32, s.won)
	for i, r in ipairs(s.rolls) do
		local y = -60 - (i - 1) * 18
		fs(tip, "GameFontHighlightSmall", nil, 12, y, name(r[1], r[2]))
		rfs(tip, "GameFontHighlightSmall", { 0.85, 0.85, 0.85 }, -12, y, r[3])
	end
end

function DRAW.facts(p, s)
	local facts = box(p, 24, -12, 220, 146, { 0.09, 0.07, 0.05, 0.85 }, { 0.45, 0.36, 0.2 })
	local rows = {
		{ s.duration, "42:17", { 1, 1, 1 } },
		{ s.wipes, "1", { 1, 0.85, 0.2 } },
		{ s.balance, ns.Parse.Coins(52857), { 0.25, 1, 0.25 } },
	}
	for i, r in ipairs(rows) do
		local y = -14 - (i - 1) * 24
		fs(facts, "GameFontNormalSmall", GOLD, 12, y, r[1])
		rfs(facts, "GameFontHighlightSmall", r[3], -12, y, r[2])
	end
	fs(facts, "GameFontNormalSmall", GOLD, 12, -96, ns.L.FACT_DEATHS)
	fs(facts, "GameFontHighlightSmall", nil, 12, -116, name("Mirela", "PRIEST"))
	rfs(facts, "GameFontHighlightSmall", { 1, 1, 1 }, -12, -116, "2")

	local hl = box(p, 262, -12, 230, 146, { 0.09, 0.07, 0.05, 0.85 }, { 0.45, 0.36, 0.2 })
	fs(hl, "GameFontNormalSmall", GOLD, 12, -10, ns.L.FACT_HIGHLIGHTS)
	local h = { { "Interface\\Icons\\Ability_Warrior_ShieldBreak", s.h1 }, { "Interface\\Icons\\INV_Misc_Coin_01", s.h2 } }
	for i, entry in ipairs(h) do
		local y = -34 - (i - 1) * 50
		icon(hl, 12, y, 34, entry[1])
		fs(hl, "GameFontDisableSmall", GREY, 54, y - 2, entry[2][1])
		fs(hl, "GameFontHighlightSmall", { 1, 1, 1 }, 54, y - 18, entry[2][2])
	end
end

function DRAW.options(p, s)
	icon(p, 40, -36, 64, "Interface\\Icons\\INV_Box_02")
	fs(p, "GameFontNormalLarge", GOLD, 130, -30, s.head)
	fs(p, "GameFontHighlight", TEXT, 130, -56, s.line)
	local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	b:SetSize(150, 24)
	b:SetPoint("TOPLEFT", 130, -80)
	b:SetText(ns.TourUI().preview)
	b:SetScript("OnClick", function()
		if frame then frame:Hide() end
		if ns.Demo then ns.Demo.Show() end
	end)
	p.Preview = b
	fs(p, "GameFontDisableSmall", GREY, 130, -116, s.slash)
end

local function picture(i, page)
	local p = pictures[i]
	if p then return p end
	p = CreateFrame("Frame", nil, frame.Box)
	p:SetAllPoints(frame.Box)
	local draw = DRAW[page.ill]
	if draw then
		local ok, err = pcall(draw, p, page.s or {})
		if not ok then ns.Debug("tour picture " .. tostring(page.ill) .. ": " .. tostring(err)) end
	end
	pictures[i] = p
	return p
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

local function button(label, w, fn, primary)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(w, 26)
	b:SetText(label)
	b:SetScript("OnClick", fn)
	if primary and b.GetFontString then
		local text = b:GetFontString()
		if text and text.SetTextColor then text:SetTextColor(1, 0.82, 0) end
	end
	return b
end

local function dot(parent, x, y, size)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetTexture("Interface\\Buttons\\WHITE8X8")
	t:SetSize(size, size)
	t:SetPoint("TOPLEFT", x, y)
	return t
end

local function create()
	local u = ns.TourUI()
	frame = CreateFrame("Frame", "RunRecapTour", UIParent, "BackdropTemplate")
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", 0, 60)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	if frame.SetBackdrop then
		frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
		frame:SetBackdropColor(0.05, 0.043, 0.035, 0.97)
		frame:SetBackdropBorderColor(0.6, 0.48, 0.25, 1)
	end

	frame.Title = fs(frame, "GameFontNormalHuge", GOLD, PAD, -18, u.title)
	frame.Counter = fs(frame, "GameFontDisable", GREY)
	frame.Counter:SetPoint("TOPRIGHT", -44, -24)
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)
	frame.Close = close

	frame.Dots = {}
	for i = 1, #ns.TourPages() do
		frame.Dots[i] = dot(frame, PAD + (i - 1) * 14, -48, 7)
	end

	frame.Box = box(frame, PAD, BOX_Y, BOX_W, BOX_H, { 0.15, 0.11, 0.08 }, { 0.35, 0.28, 0.18 })

	local textY = BOX_Y - BOX_H - 18
	frame.PageTitle = fs(frame, "GameFontNormalLarge", GOLD, PAD, textY)
	frame.Text = fs(frame, "GameFontHighlight", TEXT, PAD, textY - 28)
	frame.Text:SetWidth(WIDTH - 2 * PAD)
	frame.Text:SetWordWrap(true)
	frame.Tip = fs(frame, "GameFontHighlightSmall", GREEN)
	frame.Tip:SetWidth(WIDTH - 2 * PAD)

	frame.Line = frame:CreateTexture(nil, "ARTWORK")
	frame.Line:SetColorTexture(0.55, 0.44, 0.24, 0.6)
	frame.Line:SetHeight(1)
	frame.Line:SetPoint("BOTTOMLEFT", PAD, 54)
	frame.Line:SetPoint("BOTTOMRIGHT", -PAD, 54)

	frame.Next = button(u.next, 100, function() Tour.Go(frame.page + 1) end, true)
	frame.Next:SetPoint("BOTTOMRIGHT", -PAD, 16)
	frame.Back = button(u.back, 100, function() Tour.Go(frame.page - 1) end)
	frame.Back:SetPoint("RIGHT", frame.Next, "LEFT", -8, 0)
	frame.WhatsNew = button(u.whatsNew, 124, function()
		frame:Hide()
		if ns.WhatsNew then ns.WhatsNew.ShowPage(ns.VERSION) end
	end)
	frame.WhatsNew:SetPoint("BOTTOMLEFT", PAD, 16)
	frame.Options = button(u.options, 124, function() Tour.OpenOptions() end)
	frame.Options:SetPoint("LEFT", frame.WhatsNew, "RIGHT", 8, 0)

	frame:SetScript("OnHide", function() if ns.Popup then ns.Popup.Close() end end)
	ns.Widgets.CloseOnEscape(frame)
	frame:Hide()
end

-- Shows page i.
function Tour.Go(i)
	if not frame then create() end
	local pages = ns.TourPages()
	if i < 1 or i > #pages then
		if i > #pages then frame:Hide() end
		return frame
	end
	frame.page = i
	local page = pages[i]
	local u = ns.TourUI()
	local last = i == #pages
	for k, p in pairs(pictures) do p:SetShown(k == i) end
	picture(i, page):Show()
	for k, d in ipairs(frame.Dots) do
		if k == i then d:SetVertexColor(1, 0.82, 0)
		elseif k < i then d:SetVertexColor(0.59, 0.47, 0.24)
		else d:SetVertexColor(0.27, 0.23, 0.16) end
	end
	frame.Counter:SetText(i .. " / " .. #pages)
	frame.PageTitle:SetText(page.title)
	frame.Text:SetText(page.text)
	frame.Tip:ClearAllPoints()
	frame.Tip:SetPoint("TOPLEFT", frame.Text, "BOTTOMLEFT", 0, -6)
	frame.Tip:SetText(page.tip and ("› " .. page.tip) or "")
	frame.Tip:SetShown(page.tip ~= nil)
	frame.Back:SetShown(i > 1)
	frame.Next:SetText(last and u.done or u.next)
	frame.WhatsNew:SetShown(last)
	frame.Options:SetShown(last)
	return frame
end

-- Opens the tour on its first page (login, options button, /recap tour).
function Tour.Show()
	if ns.db then ns.db.tourSeen = true end
	local f = Tour.Go(1)
	f:Show()
	if f.Raise then f:Raise() end
	return f
end

-- Last page: the options (Blizzard's settings panel cannot open in combat).
function Tour.OpenOptions()
	if InCombatLockdown and InCombatLockdown() then
		ns.Print(ns.TourUI().combat)
		return
	end
	frame:Hide()
	if ns.Options and ns.Options.Open then ns.Options.Open() end
end

-- Due once: new installs and everybody who has not seen it yet.
function Tour.Due()
	return ns.db ~= nil and not ns.db.tourSeen
end

function Tour.Frame() return frame end
