local _, ns = ...

--[[
Success moment after the last boss (Banner v2): sound, then a banner fades in at the spot
where the recap opens, stays ~3 s, fades out - then the recap window opens (after combat).
A click on the banner skips it. Own, unprotected frame: may show in combat; during combat
it does not take mouse clicks, so it never blocks targeting.
]]

local Banner = {}
ns.Banner = Banner

Banner.FADE_IN, Banner.HOLD, Banner.FADE_OUT = 0.4, 3.0, 0.7

-- Sounds that exist in the Forever client (probe 21.11.2026; 12891 is missing). 0 = off.
Banner.SOUNDS = { 878, 888, 17316, 8455, 8454, 8959, 8960, 0 }

local W = ns.Widgets
local frame
local pendingRun      -- recap waiting for the end of combat
local current, onDoneFn -- run on the banner, replacement for "open the recap"

local function inCombat() return InCombatLockdown and InCombatLockdown() end

function Banner.PlaySound(id)
	id = id or (ns.db and ns.db.sound)
	if not id or id == 0 or not PlaySound then return false end
	local ok, willPlay = pcall(PlaySound, id, "Master")
	return ok and willPlay ~= false
end

local function openRecap(run)
	if not run or not ns.Recap then return end
	if inCombat() then
		pendingRun = run
	else
		pendingRun = nil
		ns.Recap.Show(run)
	end
end

function Banner.OnCombatEnd()
	if pendingRun and not (frame and frame:IsShown()) then openRecap(pendingRun) end
end

local function finish()
	if not frame then return end
	frame:SetScript("OnUpdate", nil)
	frame:Hide()
	local run, done = current, onDoneFn
	current, onDoneFn = nil, nil
	if done then
		done(run)
	else
		openRecap(run)
	end
end
Banner.Finish = finish

local function create()
	frame = CreateFrame("Button", "RunRecapBanner", UIParent)
	frame:SetSize(1100, 245)
	frame:SetFrameStrata("HIGH")
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame:SetScript("OnClick", finish)

	local band = frame:CreateTexture(nil, "BACKGROUND")
	band:SetTexture(W.MEDIA .. "Banner")
	band:SetAllPoints()

	local top = frame:CreateTexture(nil, "ARTWORK")
	top:SetTexture(W.MEDIA .. "BannerLine")
	top:SetSize(930, 8)
	top:SetPoint("TOP", 0, -32)
	local bottom = frame:CreateTexture(nil, "ARTWORK")
	bottom:SetTexture(W.MEDIA .. "BannerLine")
	bottom:SetSize(930, 8)
	bottom:SetPoint("BOTTOM", 0, 32)

	frame.Glow = frame:CreateTexture(nil, "BORDER")
	frame.Glow:SetTexture(W.MEDIA .. "BannerGlow")
	frame.Glow:SetBlendMode("ADD")
	frame.Glow:SetSize(780, 135)
	frame.Glow:SetPoint("CENTER", 0, 32)
	frame.Glow:SetAlpha(0.55)

	frame.Title = W.Text(frame, ns.Fonts.BannerTitle(54), W.GOLD, "OVERLAY")
	frame.Title:SetJustifyH("CENTER")
	frame.Title:SetPoint("CENTER", 0, 32)
	frame.Title:SetShadowColor(0, 0, 0, 0.9)
	frame.Title:SetShadowOffset(2, -2)

	frame.Name = W.Text(frame, ns.Fonts.BannerText(27), { 0.95, 0.93, 0.88 }, "OVERLAY")
	frame.Name:SetJustifyH("CENTER")
	frame.Name:SetPoint("TOP", frame.Title, "BOTTOM", 0, -10)
	frame.Name:SetShadowColor(0, 0, 0, 0.9)
	frame.Name:SetShadowOffset(1, -1)

	frame.Status = W.Text(frame, ns.Fonts.BannerText(18), W.GREY, "OVERLAY")
	frame.Status:SetJustifyH("CENTER")
	frame.Status:SetPoint("TOP", frame.Name, "BOTTOM", 0, -7)
	frame:Hide()
end

local function onUpdate(self, elapsed)
	self.t = (self.t or 0) + elapsed
	local t, a = self.t, 1
	if t < Banner.FADE_IN then
		a = t / Banner.FADE_IN
	elseif t > Banner.FADE_IN + Banner.HOLD then
		a = 1 - (t - Banner.FADE_IN - Banner.HOLD) / Banner.FADE_OUT
	end
	if a <= 0 then
		finish()
		return
	end
	self:SetAlpha(math.min(1, a))
	if self.EnableMouse then self:EnableMouse(not inCombat()) end
end

-- "1 wipe" / "3 wipes" in the client's language
function ns.WipesText(n)
	n = n or 0
	return n == 1 and ns.L.WIPE_ONE or ns.L.WIPES_N:format(n)
end

function Banner.StatusLine(run)
	local L = ns.L
	local s = ns.Run.Summary(run, true)
	return L.BANNER_STATUS:format(ns.Parse.Clock(s.duration), s.done, s.total, ns.WipesText(s.wipes))
end

-- Shows the banner for `run`. onDone(run) replaces "open the recap" (used by the preview).
function Banner.Show(run, onDone)
	if not frame then create() end
	local L = ns.L
	current, onDoneFn = run, onDone
	frame.Title:SetText(L.BANNER_TITLE)
	frame.Name:SetText(run.name or "")
	frame.Status:SetText(Banner.StatusLine(run))
	frame.t = 0
	frame:SetAlpha(0)
	frame:EnableMouse(not inCombat())
	frame:Show()
	frame:SetScript("OnUpdate", onUpdate)
	return frame
end

function Banner.IsShown() return frame and frame:IsShown() or false end

-- A wing/dungeon was completed (Run.onComplete).
function Banner.Celebrate(run)
	if not ns.db then return end
	Banner.PlaySound()
	if not ns.db.autoOpen then
		ns.Print(ns.L.DONE_CHAT:format(run.name or ""))
		return
	end
	if ns.Recap and ns.Recap.IsShown() then ns.Recap.Hide() end
	Banner.Show(run)
end
