--[[
Minimap button (Felix, 23.11.2026): left-click opens/closes the recap of the last run,
right-click the options. Built with LibDataBroker + LibDBIcon (in Libs/), so minimap button
collectors and broker bars (Titan Panel, ChocolateBar) pick it up. Position and visibility
are saved in RunRecapDB.minimap.
]]
local _, ns = ...
local MinimapButton = {}
ns.MinimapButton = MinimapButton

local NAME = "RunRecap"
local registered = false

local function libs()
	if not LibStub then return nil end
	return LibStub("LibDataBroker-1.1", true), LibStub("LibDBIcon-1.0", true)
end

function MinimapButton.OnClick(button)
	if button == "RightButton" then
		if ns.Options then ns.Options.Open() end
		return
	end
	local run = ns.Run.Latest()
	if run and ns.Recap then
		ns.Recap.Toggle(run)
	else
		ns.Print(ns.L.NO_RECAP_YET)
	end
end

function MinimapButton.Tooltip(tt)
	local L = ns.L
	tt:AddLine(L.ADDON_TITLE, 1, 0.82, 0)
	local run = ns.Run.Latest()
	if run then
		local duration = run.completedAt or ns.Run.Elapsed(run)
		tt:AddLine(L.MINIMAP_LAST:format(run.name or "?", ns.Parse.Clock(duration)), 0.6, 0.6, 0.6)
	else
		tt:AddLine(L.MINIMAP_NONE, 0.6, 0.6, 0.6)
	end
	tt:AddLine(" ")
	tt:AddLine(L.MINIMAP_LEFT, 0.1, 1, 0.1)
	tt:AddLine(L.MINIMAP_RIGHT, 0.1, 1, 0.1)
end

function MinimapButton.Init()
	if registered or not ns.db then return end
	local ldb, icon = libs()
	if not ldb or not icon then return end
	ns.db.minimap = ns.db.minimap or { hide = false }
	local object = ldb:NewDataObject(NAME, {
		type = "launcher",
		text = ns.L.ADDON_TITLE,
		icon = ns.ICON,
		OnClick = function(_, button) MinimapButton.OnClick(button) end,
		OnTooltipShow = function(tt) MinimapButton.Tooltip(tt) end,
	})
	if not object then return end
	icon:Register(NAME, object, ns.db.minimap)
	registered = true
end

function MinimapButton.SetShown(show)
	if not ns.db then return end
	ns.db.minimap = ns.db.minimap or {}
	ns.db.minimap.hide = not show
	local _, icon = libs()
	if not icon or not registered then return end
	if show then icon:Show(NAME) else icon:Hide(NAME) end
end

function MinimapButton.IsShown()
	return not (ns.db and ns.db.minimap and ns.db.minimap.hide)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() MinimapButton.Init() end)
