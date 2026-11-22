local _, ns = ...

--[[
Options: AddOns section of the game settings (as in BGF), falls back to a standalone window.
0.1 has one page: open automatically, green items, look (skin), success sound (choice,
preview, off), preview of banner and recap. Always native look, whatever the recap skin.
]]

local Options = {}
ns.Options = Options

local W = ns.Widgets
local panel, category, container

function Options.SoundName(id)
	local L = ns.L
	if not id or id == 0 then return L.SOUND_OFF end
	local name = L["SOUND_" .. id]
	if name == "SOUND_" .. id then name = tostring(id) end
	return name
end

function Options.SkinName(skin)
	local L = ns.L
	return skin == "recap" and L.SKIN_RECAP or L.SKIN_BLIZZARD
end

local function build()
	local L = ns.L
	panel = CreateFrame("Frame", "RunRecapOptions")
	panel.name = L.ADDON_TITLE
	panel:Hide()   -- the settings window shows it (OnShow then refreshes the values)

	local title = W.Text(panel, ns.Fonts.Game(16), W.GOLD)
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(L.ADDON_TITLE .. "  |cff808080" .. ns.VERSION .. "|r")
	local desc = W.Text(panel, ns.Fonts.Game(12), { 1, 1, 1 })
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	desc:SetWidth(600)
	desc:SetText(L.OPT_DESC)

	local auto = W.Check(panel, L.OPT_AUTO_OPEN, function() return ns.db.autoOpen end,
		function(v) ns.db.autoOpen = v end)
	auto:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -2, -16)
	local autoHint = W.Text(panel, ns.Fonts.Game(11), W.GREY)
	autoHint:SetPoint("TOPLEFT", auto.Label, "BOTTOMLEFT", 0, -2)
	autoHint:SetWidth(560)
	autoHint:SetText(L.OPT_AUTO_OPEN_HINT)

	local green = W.Check(panel, L.OPT_SHOW_GREEN, function() return ns.db.showGreen end, function(v)
		ns.db.showGreen = v
		if ns.Recap and ns.Recap.IsShown() then ns.Recap.Render() end
	end)
	green:SetPoint("TOPLEFT", auto, "BOTTOMLEFT", 0, -26)

	local skinLabel = W.Text(panel, ns.Fonts.Game(12), { 1, 1, 1 })
	skinLabel:SetPoint("TOPLEFT", green, "BOTTOMLEFT", 4, -22)
	skinLabel:SetWidth(130)
	skinLabel:SetText(L.OPT_SKIN)
	local skinDrop
	skinDrop = W.Dropdown(panel, 220, function()
		local items = {}
		for _, skin in ipairs(W.SKINS) do
			items[#items + 1] = { kind = "button", checked = (ns.db.skin or "blizzard") == skin, text = Options.SkinName(skin), fn = function()
				ns.db.skin = skin
				skinDrop:SetValue(Options.SkinName(skin))
				if ns.Recap and ns.Recap.ApplySkin then ns.Recap.ApplySkin() end
			end }
		end
		return items
	end)
	skinDrop:SetPoint("LEFT", skinLabel, "RIGHT", 4, 0)

	local soundLabel = W.Text(panel, ns.Fonts.Game(12), { 1, 1, 1 })
	soundLabel:SetPoint("TOPLEFT", skinLabel, "BOTTOMLEFT", 0, -24)
	soundLabel:SetWidth(130)
	soundLabel:SetText(L.OPT_SOUND)
	local soundButton
	local play = W.Button(panel, L.OPT_SOUND_PLAY)
	play:SetScript("OnClick", function() ns.Banner.PlaySound() end)
	local soundHint = W.Text(panel, ns.Fonts.Game(11), W.GREY)
	soundHint:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 0, -10)
	soundHint:SetWidth(560)
	soundHint:SetText(L.OPT_SOUND_HINT)

	local function refreshSound()
		soundButton:SetValue(Options.SoundName(ns.db.sound))
		skinDrop:SetValue(Options.SkinName(ns.db.skin))
		play:SetEnabled((ns.db.sound or 0) ~= 0)
		play:SetAlpha((ns.db.sound or 0) ~= 0 and 1 or 0.5)
	end
	soundButton = W.Dropdown(panel, 220, function()
		local items = {}
		for _, id in ipairs(ns.Banner.SOUNDS) do
			items[#items + 1] = { kind = "button", checked = (ns.db.sound or 0) == id, text = Options.SoundName(id), fn = function()
				ns.db.sound = id
				refreshSound()
				ns.Banner.PlaySound(id)
			end }
		end
		return items
	end)
	soundButton:SetPoint("LEFT", soundLabel, "RIGHT", 4, 0)
	play:SetPoint("LEFT", soundButton, "RIGHT", 8, 0)

	local previewLabel = W.Text(panel, ns.Fonts.Game(14), W.GOLD)
	previewLabel:SetPoint("TOPLEFT", soundHint, "BOTTOMLEFT", 0, -28)
	previewLabel:SetText(L.OPT_PREVIEW_TITLE)
	local preview = W.Button(panel, L.OPT_PREVIEW)
	preview:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 0, -10)
	preview:SetScript("OnClick", function() if ns.Demo then ns.Demo.Show() end end)
	local previewHint = W.Text(panel, ns.Fonts.Game(11), W.GREEN)
	previewHint:SetPoint("LEFT", preview, "RIGHT", 12, 0)
	previewHint:SetText(L.OPT_PREVIEW_HINT)

	local tourButton = W.Button(panel, L.OPT_TOUR)
	tourButton:SetPoint("LEFT", previewHint, "RIGHT", 16, 0)
	tourButton:ClearAllPoints()
	tourButton:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -14)
	tourButton:SetScript("OnClick", function() if ns.Tour then ns.Tour.Show() end end)
	local newsButton = W.Button(panel, L.OPT_NEWS)
	newsButton:SetPoint("LEFT", tourButton, "RIGHT", 8, 0)
	newsButton:SetScript("OnClick", function() if ns.WhatsNew then ns.WhatsNew.ShowPage(ns.VERSION) end end)
	local newsCheck = W.Check(panel, L.OPT_NEWS_SHOW, function() return ns.db.showWhatsNew ~= false end,
		function(v) ns.db.showWhatsNew = v end)
	newsCheck:SetPoint("LEFT", newsButton, "RIGHT", 12, 0)
	panel.Tour, panel.News, panel.NewsCheck = tourButton, newsButton, newsCheck

	local slash = W.Text(panel, ns.Fonts.Game(11), W.GREY)
	slash:SetPoint("TOPLEFT", tourButton, "BOTTOMLEFT", 0, -24)
	slash:SetWidth(600)
	slash:SetText(L.SLASH_HELP)

	panel:SetScript("OnShow", refreshSound)
	if ns.db then refreshSound() end
	panel.Auto, panel.Green, panel.SoundButton, panel.Play, panel.Preview, panel.SkinDrop = auto, green, soundButton, play, preview, skinDrop

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, panel, L.ADDON_TITLE)
		if ok and cat then
			category = cat
			pcall(Settings.RegisterAddOnCategory, cat)
			return
		end
	end
	-- Fallback: standalone window
	container = W.NativeWindow("RunRecapOptionsWindow", UIParent)
	container:SetSize(660, 440)
	container:SetPoint("CENTER")
	container:SetFrameStrata("DIALOG")
	container:EnableMouse(true)
	container:SetMovable(true)
	container:RegisterForDrag("LeftButton")
	container:SetScript("OnDragStart", container.StartMoving)
	container:SetScript("OnDragStop", container.StopMovingOrSizing)
	local inset = W.Child(container, "Inset")
	if inset then inset:Hide() end
	W.SetTitle(container, L.ADDON_TITLE)
	W.SetPortrait(container, "Interface\\Icons\\INV_Box_02")
	W.CloseOnEscape(container)
	panel:SetParent(container)
	panel:SetPoint("TOPLEFT", 4, -60)
	panel:SetPoint("BOTTOMRIGHT", -4, 4)
	panel:Show()
	container:Hide()
end

function Options.Open()
	if not panel then build() end
	if category and Settings and Settings.OpenToCategory then
		local id = category.GetID and category:GetID() or category.ID
		if pcall(Settings.OpenToCategory, id) then return end
	end
	if container then container:Show() end
end

function Options.Panel() return panel end

-- Register the settings category once the saved variables are ready.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	if not panel and ns.db then
		local ok, err = pcall(build)
		if not ok then ns.Debug("options build failed: " .. tostring(err)) end
	end
end)
