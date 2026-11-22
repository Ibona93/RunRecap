local _, ns = ...

--[[
Options: AddOns section of the game settings (as in BGF), falls back to a standalone window.
0.1 has one page: open automatically, success sound (choice, preview, off), green items,
preview of banner and recap.
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

local function build()
	local L = ns.L
	panel = CreateFrame("Frame", "RunRecapOptions")
	panel.name = L.ADDON_TITLE
	panel:Hide()   -- the settings window shows it (OnShow then refreshes the values)

	local title = W.Text(panel, ns.Fonts.Heading(16), W.GOLD)
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(L.ADDON_TITLE .. "  |cff808080" .. ns.VERSION .. "|r")
	local desc = W.Text(panel, ns.Fonts.Text(12), { 1, 1, 1 })
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	desc:SetWidth(600)
	desc:SetText(L.OPT_DESC)

	local auto = W.Check(panel, L.OPT_AUTO_OPEN, function() return ns.db.autoOpen end,
		function(v) ns.db.autoOpen = v end)
	auto:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -2, -16)
	local autoHint = W.Text(panel, ns.Fonts.Text(11), W.GREY)
	autoHint:SetPoint("TOPLEFT", auto.Label, "BOTTOMLEFT", 0, -2)
	autoHint:SetWidth(560)
	autoHint:SetText(L.OPT_AUTO_OPEN_HINT)

	local green = W.Check(panel, L.OPT_SHOW_GREEN, function() return ns.db.showGreen end, function(v)
		ns.db.showGreen = v
		if ns.Recap and ns.Recap.IsShown() then ns.Recap.Render() end
	end)
	green:SetPoint("TOPLEFT", auto, "BOTTOMLEFT", 0, -26)

	local soundLabel = W.Text(panel, ns.Fonts.Text(12), { 1, 1, 1 })
	soundLabel:SetPoint("TOPLEFT", green, "BOTTOMLEFT", 4, -22)
	soundLabel:SetText(L.OPT_SOUND)
	local soundButton = W.Button(panel, "", 200, 24)
	soundButton:SetPoint("LEFT", soundLabel, "RIGHT", 12, 0)
	local play = W.Button(panel, L.OPT_SOUND_PLAY)
	play:SetPoint("LEFT", soundButton, "RIGHT", 8, 0)
	play:SetScript("OnClick", function() ns.Banner.PlaySound() end)
	local soundHint = W.Text(panel, ns.Fonts.Text(11), W.GREY)
	soundHint:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 0, -10)
	soundHint:SetWidth(560)
	soundHint:SetText(L.OPT_SOUND_HINT)

	local function refreshSound()
		soundButton:SetText(Options.SoundName(ns.db.sound))
		play:SetEnabled((ns.db.sound or 0) ~= 0)
		play:SetAlpha((ns.db.sound or 0) ~= 0 and 1 or 0.5)
	end
	soundButton:SetScript("OnClick", function(self)
		local items = { { kind = "title", text = L.OPT_SOUND } }
		for _, id in ipairs(ns.Banner.SOUNDS) do
			items[#items + 1] = { kind = "button", checked = (ns.db.sound or 0) == id, text = Options.SoundName(id), fn = function()
				ns.db.sound = id
				refreshSound()
				ns.Banner.PlaySound(id)
			end }
		end
		ns.Popup.Open(self, items)
	end)

	local previewLabel = W.Text(panel, ns.Fonts.Heading(14), W.GOLD)
	previewLabel:SetPoint("TOPLEFT", soundHint, "BOTTOMLEFT", 0, -28)
	previewLabel:SetText(L.OPT_PREVIEW_TITLE)
	local preview = W.Button(panel, L.OPT_PREVIEW)
	preview:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 0, -10)
	preview:SetScript("OnClick", function() if ns.Demo then ns.Demo.Show() end end)
	local previewHint = W.Text(panel, ns.Fonts.Text(11), W.GREEN)
	previewHint:SetPoint("LEFT", preview, "RIGHT", 12, 0)
	previewHint:SetText(L.OPT_PREVIEW_HINT)

	local slash = W.Text(panel, ns.Fonts.Text(11), W.GREY)
	slash:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -30)
	slash:SetWidth(600)
	slash:SetText(L.SLASH_HELP)

	panel:SetScript("OnShow", refreshSound)
	if ns.db then refreshSound() end
	panel.Auto, panel.Green, panel.SoundButton, panel.Play, panel.Preview = auto, green, soundButton, play, preview

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
