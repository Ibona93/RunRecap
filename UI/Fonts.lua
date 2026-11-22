local ADDON_NAME, ns = ...

--[[
Skin "blizzard" (default) and options/popups: the game's own font (Friz Quadrata on Latin
clients, the right font on ruRU/koKR/zhCN/zhTW) - never shipped, only referenced.
Skin "recap": Philosopher for headings, Noto Sans for text (shipped, SIL OFL; no CJK glyphs ->
game font on koKR/zhCN/zhTW).
Success banner title: shipped Cinzel Bold (SIL OFL; no Cyrillic -> game font on ruRU and CJK).
Widgets only ever get font *objects* (SetFontObject), never SetFont on a font string.
]]

local Fonts = {}
ns.Fonts = Fonts

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Fonts\\"

Fonts.HEADING = MEDIA .. "Philosopher-Regular.ttf"
Fonts.TEXT = MEDIA .. "NotoSans-Regular.ttf"
Fonts.BANNER = MEDIA .. "Cinzel-Bold.ttf"

local CJK = { koKR = true, zhCN = true, zhTW = true }

local NO_CINZEL = { ruRU = true, koKR = true, zhCN = true, zhTW = true }

local function gameFont()
	if _G.STANDARD_TEXT_FONT then return _G.STANDARD_TEXT_FONT end
	if GameFontNormal and GameFontNormal.GetFont then
		local path = GameFontNormal:GetFont()
		if path then return path end
	end
	return "Fonts\\FRIZQT__.TTF"
end

-- Path for a font role ("heading", "text", "banner", "game"), respecting the client's alphabet.
-- "heading"/"text" follow the recap window's skin; "game" is always the game font.
function Fonts.PathFor(role)
	if role == "banner" then return NO_CINZEL[ns.clientLocale] and gameFont() or Fonts.BANNER end
	if role == "game" or CJK[ns.clientLocale] then return gameFont() end
	if ns.db and ns.db.skin == "recap" then
		return role == "heading" and Fonts.HEADING or Fonts.TEXT
	end
	return gameFont()
end

Fonts.objects = {}
local cache = {}

function Fonts.GetPath(path, size, flags)
	local id = path .. "|" .. size .. "|" .. (flags or "")
	if cache[id] then return cache[id] end
	local font = CreateFont("RunRecapFont" .. (#Fonts.objects + 1))
	font:CopyFontObject(GameFontHighlightSmall)
	pcall(font.SetFont, font, path, size, flags or "")
	if not font:GetFont() then
		font:SetFont(gameFont(), size, flags or "")
	end
	cache[id] = font
	Fonts.objects[#Fonts.objects + 1] = font
	return font
end

-- Font object for headings (golden titles) and for normal text: the game font in that size.
function Fonts.Heading(size, flags) return Fonts.GetPath(Fonts.PathFor("heading"), size or 16, flags) end
function Fonts.Text(size, flags) return Fonts.GetPath(Fonts.PathFor("text"), size or 12, flags) end
-- Always the game font (options, popups, dropdowns).
function Fonts.Game(size, flags) return Fonts.GetPath(gameFont(), size or 12, flags) end
-- Success banner: big title and the lines below it.
function Fonts.BannerTitle(size, flags) return Fonts.GetPath(Fonts.PathFor("banner"), size or 32, flags) end
function Fonts.BannerText(size, flags) return Fonts.GetPath(Fonts.PathFor("game"), size or 15, flags) end
