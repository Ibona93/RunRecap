local ADDON_NAME, ns = ...

--[[
Shared look (as in BGF): dark brown/black windows, golden headings and borders, green hints.
Own small popup menu instead of Blizzard's menus, own Escape handling instead of
UISpecialFrames. Only plain, unprotected frames.
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

-- Golden separator line.
function W.Line(parent, alpha)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetColorTexture(W.BORDER[1], W.BORDER[2], W.BORDER[3], alpha or 0.6)
	t:SetHeight(1)
	return t
end

function W.Backdrop(frame, bg, border, edge)
	if not frame.SetBackdrop then return end
	frame:SetBackdrop({ bgFile = W.WHITE, edgeFile = W.WHITE, edgeSize = edge or 1 })
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
	frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

-- Main window look: dark background, golden border, warm glow at the top.
function W.Window(frame)
	W.Backdrop(frame, { 0.05, 0.043, 0.035, 0.97 }, W.BORDER, 2)
	local glow = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	glow:SetPoint("TOPLEFT", 2, -2)
	glow:SetPoint("TOPRIGHT", -2, -2)
	glow:SetHeight(90)
	glow:SetColorTexture(0.22, 0.16, 0.06, 0.4)
	if glow.SetGradient and CreateColor then
		pcall(glow.SetGradient, glow, "VERTICAL", CreateColor(0.05, 0.04, 0.03, 0), CreateColor(0.25, 0.18, 0.07, 0.55))
	end
	frame.Glow = glow
end

-- Button: gold text on dark brown with a golden border.
function W.Button(parent, text, width, height)
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(width or 100, height or 24)
	W.Backdrop(b, { 0.14, 0.1, 0.04, 0.95 }, { 0.8, 0.64, 0.25, 1 })
	b.Text = W.Text(b, ns.Fonts.Text(12), W.GOLD)
	b.Text:SetPoint("CENTER")
	b.Text:SetJustifyH("CENTER")
	b.Text:SetText(text or "")
	b:SetScript("OnEnter", function(self)
		if self.SetBackdropColor then self:SetBackdropColor(0.28, 0.2, 0.06, 0.95) end
		if self.tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.tooltip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		if self.SetBackdropColor then self:SetBackdropColor(0.14, 0.1, 0.04, 0.95) end
		if self.tooltip then GameTooltip:Hide() end
	end)
	b.SetLabel = function(self, t)
		self.Text:SetText(t)
		if not width then self:SetWidth(math.ceil(self.Text:GetStringWidth() or 60) + 28) end
	end
	if not width then b:SetLabel(text or "") end
	return b
end

function W.Check(parent, text, getter, setter)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb.Label = W.Text(cb, ns.Fonts.Text(13), { 1, 1, 1 })
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
	W.Backdrop(popup, { 0.04, 0.035, 0.03, 0.96 }, { 0.55, 0.45, 0.28, 1 })
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
	r.Text = W.Text(r, ns.Fonts.Text(12))
	r.Text:SetWordWrap(false)
	r.Line = r:CreateTexture(nil, "ARTWORK")
	r.Line:SetColorTexture(0.55, 0.45, 0.28, 0.6)
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

function Popup.Open(owner, items)
	if not popup then createPopup() end
	if popup:IsShown() and Popup.owner == owner then close() return end
	Popup.owner = owner
	local width, y = 120, -6
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
