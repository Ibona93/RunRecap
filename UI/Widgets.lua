local ADDON_NAME, ns = ...

--[[
Shared look. Two skins for the recap window (Felix, 22.11.2026):
  "blizzard" (default) - native Blizzard templates: window, insets, red panel buttons, game font
  "recap"              - Run Recap's own dark look: dark brown, golden borders, Philosopher/Noto Sans
Options and popups always look native. Own small popup menu and dropdown look instead of
Blizzard's menus (taint), own Escape handling instead of UISpecialFrames. Only plain,
unprotected frames.
]]

local W = {}
ns.Widgets = W

W.MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
W.WHITE = "Interface\\Buttons\\WHITE8X8"
W.GOLD = { 1, 0.82, 0 }
W.GREY = { 0.62, 0.62, 0.62 }
W.DARKGREY = { 0.45, 0.45, 0.45 }
W.GREEN = { 0.25, 1, 0.25 }
W.YELLOW = { 1, 0.85, 0.2 }
W.BORDER = { 0.6, 0.48, 0.25 }
W.SKINS = { "blizzard", "recap" }

local QUALITY_HEX = {
	[0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000", [6] = "e6cc80", [7] = "00ccff",
}

function W.QualityColor(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
	if c and c.r then return c.r, c.g, c.b, (c.hex and c.hex:gsub("^|c", "")) or nil end
	local hex = QUALITY_HEX[q or 1] or "ffffff"
	return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

function W.QualityHex(q)
	return "ff" .. (QUALITY_HEX[q or 1] or "ffffff")
end

-- Player name in class colour (white if the class is unknown).
function W.ClassHex(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then
		if c.colorStr then return c.colorStr end
		return ("ff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
	end
	return "ffffffff"
end

function W.ColorName(name, class)
	return "|c" .. W.ClassHex(class) .. tostring(name) .. "|r"
end

function W.Hex(rgb)
	return ("ff%02x%02x%02x"):format(rgb[1] * 255, rgb[2] * 255, rgb[3] * 255)
end

function W.Colored(text, rgb)
	return "|c" .. W.Hex(rgb) .. tostring(text) .. "|r"
end

function W.Text(parent, font, rgb, layer)
	local fs = parent:CreateFontString(nil, layer or "ARTWORK")
	fs:SetFontObject(font or ns.Fonts.Text(12))
	fs:SetJustifyH("LEFT")
	if rgb then fs:SetTextColor(rgb[1], rgb[2], rgb[3]) end
	return fs
end

function W.Backdrop(frame, bg, border, edge)
	if not frame.SetBackdrop then return end
	frame:SetBackdrop({ bgFile = W.WHITE, edgeFile = W.WHITE, edgeSize = edge or 1 })
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
	frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

-- Native window: Blizzard's ButtonFrameTemplate (portrait, title bar, close button), else
-- BasicFrameTemplateWithInset, else a plain dialog backdrop. Returns frame, kind.
function W.NativeWindow(name, parent)
	for _, template in ipairs({ "ButtonFrameTemplate", "BasicFrameTemplateWithInset" }) do
		local ok, f = pcall(CreateFrame, "Frame", name, parent or UIParent, template)
		if ok and f then
			f.template = template
			return f, template
		end
	end
	local f = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
	if f.SetBackdrop then
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
	end
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)
	f.CloseButton = close
	f.template = "backdrop"
	return f, "backdrop"
end

-- A child region a template created (table), or nil.
function W.Child(f, key)
	local v = rawget(f, key)
	return type(v) == "table" and v or nil
end

-- Title in the window's title bar (the template's own title text where there is one).
function W.SetTitle(f, text)
	if f.SetTitle then
		local ok = pcall(f.SetTitle, f, text)
		if ok then return end
	end
	local tc = W.Child(f, "TitleContainer")
	local fs = W.Child(f, "TitleText") or (tc and W.Child(tc, "TitleText"))
	if not fs then
		fs = W.Text(f, ns.Fonts.Game(13), W.GOLD, "OVERLAY")
		fs:SetPoint("TOP", 0, -6)
		f.TitleText = fs
	end
	fs:SetText(text)
end

-- Portrait (round, top left) of a ButtonFrameTemplate window; nothing for other templates.
function W.SetPortrait(f, texture)
	local container = W.Child(f, "PortraitContainer")
	local portrait = W.Child(f, "portrait") or W.Child(f, "Portrait") or (container and W.Child(container, "portrait"))
	if not portrait then return false end
	if SetPortraitToTexture then
		local ok = pcall(SetPortraitToTexture, portrait, texture)
		if ok then return true end
	end
	portrait:SetTexture(texture)
	return true
end

-- The sunken inner box of Blizzard windows (InsetFrameTemplate), else a dark backdrop.
function W.Inset(parent)
	local ok, f = pcall(CreateFrame, "Frame", nil, parent, "InsetFrameTemplate")
	if ok and f then return f end
	f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	W.Backdrop(f, { 0, 0, 0, 0.45 }, { 0.3, 0.3, 0.3, 1 })
	return f
end

-- Blizzard's red panel button. Width from the text if none is given.
function W.Button(parent, text, width, height)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width or 100, height or 22)
	b.SetLabel = function(self, t)
		self:SetText(t)
		if not width then
			local w = self.GetTextWidth and self:GetTextWidth() or nil
			self:SetWidth(math.ceil(w or 60) + 30)
		end
	end
	b:SetLabel(text or "")
	b:HookScript("OnEnter", function(self)
		if self.tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.tooltip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	b:HookScript("OnLeave", function(self)
		if self.tooltip then GameTooltip:Hide() end
	end)
	return b
end

function W.Check(parent, text, getter, setter)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb.Label = W.Text(cb, ns.Fonts.Game(12), { 1, 1, 1 })
	cb.Label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	cb.Label:SetText(text)
	cb:SetScript("OnShow", function(self) self:SetChecked(getter() and true or false) end)
	cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
	if ns.db then cb:SetChecked(getter() and true or false) end
	return cb
end

-- Scroll frame with a scroll child; falls back to mouse wheel only without the template.
function W.Scroll(parent)
	local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	if not ok or not scroll then scroll = CreateFrame("ScrollFrame", nil, parent) end
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local max = self:GetVerticalScrollRange() or 0
		self:SetVerticalScroll(math.max(0, math.min(max, (self:GetVerticalScroll() or 0) - delta * 40)))
	end)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(10, 10)
	scroll:SetScrollChild(content)
	scroll.Content = content
	return scroll
end

-- Escape closes the window, without UISpecialFrames; out of combat only (as in BGF).
function W.CloseOnEscape(f, onClose)
	f:HookScript("OnShow", function(self)
		local combat = InCombatLockdown and InCombatLockdown()
		self:EnableKeyboard(not combat)
		if not combat and self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
	end)
	f:SetScript("OnKeyDown", function(self, key)
		if InCombatLockdown and InCombatLockdown() then return end
		if key == "ESCAPE" then
			if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
			if onClose then onClose() else self:Hide() end
		elseif self.SetPropagateKeyboardInput then
			self:SetPropagateKeyboardInput(true)
		end
	end)
end


-------------------------------------------------------------------------------
-- Skins
-------------------------------------------------------------------------------

-- Run Recap's own dark window: dark background, golden border, warm glow at the top.
function W.DarkWindow(name, parent)
	local f = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
	W.Backdrop(f, { 0.05, 0.043, 0.035, 0.97 }, W.BORDER, 2)
	local glow = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	glow:SetPoint("TOPLEFT", 2, -2)
	glow:SetPoint("TOPRIGHT", -2, -2)
	glow:SetHeight(90)
	glow:SetColorTexture(0.22, 0.16, 0.06, 0.4)
	if glow.SetGradient and CreateColor then
		pcall(glow.SetGradient, glow, "VERTICAL", CreateColor(0.05, 0.04, 0.03, 0), CreateColor(0.25, 0.18, 0.07, 0.55))
	end
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)
	f.CloseButton = close
	f.template = "dark"
	return f
end

function W.SkinWindow(name, skin)
	if skin == "recap" then return W.DarkWindow(name) end
	return (W.NativeWindow(name))
end

function W.SkinInset(parent, skin)
	if skin == "recap" then
		local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
		W.Backdrop(f, { 0.09, 0.07, 0.05, 0.85 }, { 0.45, 0.36, 0.2, 1 })
		return f
	end
	return W.Inset(parent)
end

-- Gold text on dark brown with a golden border (the "recap" skin's button).
function W.FlatButton(parent, text, width, height)
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(width or 100, height or 22)
	W.Backdrop(b, { 0.14, 0.1, 0.04, 0.95 }, { 0.8, 0.64, 0.25, 1 })
	b.Label = W.Text(b, ns.Fonts.Text(12), W.GOLD)
	b.Label:SetPoint("CENTER")
	b.Label:SetJustifyH("CENTER")
	b.Label:SetText(text or "")
	b:SetScript("OnEnter", function(self) if self.SetBackdropColor then self:SetBackdropColor(0.28, 0.2, 0.06, 0.95) end end)
	b:SetScript("OnLeave", function(self) if self.SetBackdropColor then self:SetBackdropColor(0.14, 0.1, 0.04, 0.95) end end)
	return b
end

function W.SkinButton(parent, text, width, height, skin)
	if skin == "recap" then return W.FlatButton(parent, text, width, height) end
	return W.Button(parent, text, width, height)
end

-- Thin separator line inside a box.
function W.Separator(parent, skin)
	local t = parent:CreateTexture(nil, "ARTWORK")
	if skin == "recap" then
		t:SetColorTexture(W.BORDER[1], W.BORDER[2], W.BORDER[3], 0.6)
	else
		t:SetColorTexture(0.6, 0.6, 0.6, 0.35)
	end
	t:SetHeight(1)
	return t
end

-------------------------------------------------------------------------------
-- Dropdown look (like the game's dropdowns: dark field, yellow arrow button); the list is
-- our own popup. items(): popup items; text: shown value.
-------------------------------------------------------------------------------

function W.Dropdown(parent, width, items)
	local d = CreateFrame("Button", nil, parent, "BackdropTemplate")
	d:SetSize(width or 200, 24)
	if d.SetBackdrop then
		d:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		d:SetBackdropColor(0, 0, 0, 0.75)
		d:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
	end
	d.Value = W.Text(d, ns.Fonts.Game(12), { 1, 1, 1 })
	d.Value:SetPoint("LEFT", 9, 0)
	d.Value:SetPoint("RIGHT", -28, 0)
	d.Value:SetWordWrap(false)
	d.Arrow = CreateFrame("Button", nil, d)
	d.Arrow:SetSize(24, 24)
	d.Arrow:SetPoint("RIGHT", 1, 0)
	d.Arrow:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	d.Arrow:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
	d.Arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	local function open() ns.Popup.Open(d, items(), d:GetWidth()) end
	d:SetScript("OnClick", open)
	d.Arrow:SetScript("OnClick", open)
	d:SetScript("OnEnter", function(self) if self.SetBackdropBorderColor then self:SetBackdropBorderColor(1, 0.82, 0, 1) end end)
	d:SetScript("OnLeave", function(self) if self.SetBackdropBorderColor then self:SetBackdropBorderColor(0.55, 0.55, 0.55, 1) end end)
	d.SetValue = function(self, text) self.Value:SetText(text or "") end
	return d
end

-------------------------------------------------------------------------------
-- Popup menu (from BGF): items = { { kind = "title"|"button"|"divider", text, fn, checked } }
-------------------------------------------------------------------------------

local Popup = {}
ns.Popup = Popup
local ROW_H, PAD = 18, 10
local popup, catcher
local rows = {}

local function close()
	if popup then popup:Hide() end
	if catcher then catcher:Hide() end
	Popup.owner = nil
end
Popup.Close = close

local function createPopup()
	catcher = CreateFrame("Button", nil, UIParent)
	catcher:SetAllPoints(UIParent)
	catcher:SetFrameStrata("FULLSCREEN")
	catcher:RegisterForClicks("AnyDown")
	catcher:SetScript("OnClick", close)
	catcher:Hide()
	popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	popup:SetFrameStrata("FULLSCREEN_DIALOG")
	popup:SetClampedToScreen(true)
	popup:EnableMouse(true)
	-- tooltip look, like Blizzard's own dropdown lists
	if popup.SetBackdrop then
		popup:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		popup:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
		popup:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
	end
	popup:SetScript("OnHide", function() if catcher then catcher:Hide() end end)
	popup:Hide()
	W.CloseOnEscape(popup, close)
end

local function popupRow(i)
	if rows[i] then return rows[i] end
	local r = CreateFrame("Button", nil, popup)
	r:SetHeight(ROW_H)
	r.Highlight = r:CreateTexture(nil, "HIGHLIGHT")
	r.Highlight:SetAllPoints()
	r.Highlight:SetColorTexture(1, 0.82, 0, 0.12)
	r.Dot = r:CreateTexture(nil, "ARTWORK")
	r.Dot:SetTexture(W.WHITE)
	r.Dot:SetSize(6, 6)
	r.Dot:SetPoint("LEFT", PAD - 2, 0)
	r.Text = W.Text(r, ns.Fonts.Game(12))
	r.Text:SetWordWrap(false)
	r.Line = r:CreateTexture(nil, "ARTWORK")
	r.Line:SetColorTexture(0.6, 0.6, 0.6, 0.4)
	r.Line:SetHeight(1)
	r.Line:SetPoint("LEFT", PAD, 0)
	r.Line:SetPoint("RIGHT", -PAD, 0)
	r:SetScript("OnClick", function(self)
		local item = self.item
		if not item or item.kind ~= "button" then return end
		close()
		if item.fn then item.fn() end
	end)
	rows[i] = r
	return r
end

function Popup.Open(owner, items, minWidth)
	if not popup then createPopup() end
	if popup:IsShown() and Popup.owner == owner then close() return end
	Popup.owner = owner
	local width, y = minWidth or 120, -6
	for i, item in ipairs(items) do
		local r = popupRow(i)
		r.item = item
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", 0, y)
		r:SetPoint("TOPRIGHT", 0, y)
		r.Line:SetShown(item.kind == "divider")
		r.Text:SetShown(item.kind ~= "divider")
		r.Dot:SetShown(item.checked ~= nil)
		if item.checked ~= nil then
			if item.checked then r.Dot:SetVertexColor(1, 0.82, 0) else r.Dot:SetVertexColor(0.35, 0.33, 0.3) end
		end
		r:EnableMouse(item.kind == "button")
		if item.kind == "divider" then
			r:SetHeight(9)
			y = y - 9
		else
			r:SetHeight(ROW_H)
			r.Text:SetText(item.text or "")
			if item.kind == "title" then r.Text:SetTextColor(1, 0.82, 0) else r.Text:SetTextColor(1, 1, 1) end
			local x = PAD + (item.checked ~= nil and 10 or 0)
			r.Text:ClearAllPoints()
			r.Text:SetPoint("LEFT", x, 0)
			width = math.max(width, (r.Text:GetStringWidth() or 0) + x + PAD)
			y = y - ROW_H
		end
		r:Show()
	end
	for i = #items + 1, #rows do rows[i]:Hide() end
	popup:SetSize(math.ceil(width), -y + 6)
	popup:ClearAllPoints()
	popup:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
	catcher:Show()
	popup:Show()
	popup:Raise()
end
