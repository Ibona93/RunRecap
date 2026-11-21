local ADDON_NAME, ns = ...

--[[
Fonts, as in BGF: Philosopher for headings, Noto Sans for text (both shipped, SIL OFL).
Korean and Chinese clients use the game font, since the shipped files have no CJK glyphs.
Success banner: Cinzel Bold for the title (no Cyrillic -> game font on ruRU and CJK), the game's
own font (Friz Quadrata on Latin clients) for the lines below - never shipped, only referenced.
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
function Fonts.PathFor(role)
	if role == "game" then return gameFont() end
	if role == "banner" then return NO_CINZEL[ns.clientLocale] and gameFont() or Fonts.BANNER end
	if CJK[ns.clientLocale] then return gameFont() end
	return role == "heading" and Fonts.HEADING or Fonts.TEXT
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

-- Font object for headings (golden titles) and for normal text.
function Fonts.Heading(size, flags) return Fonts.GetPath(Fonts.PathFor("heading"), size or 16, flags) end
function Fonts.Text(size, flags) return Fonts.GetPath(Fonts.PathFor("text"), size or 12, flags) end
-- Success banner: big title and the lines below it.
function Fonts.BannerTitle(size, flags) return Fonts.GetPath(Fonts.PathFor("banner"), size or 32, flags) end
function Fonts.BannerText(size, flags) return Fonts.GetPath(Fonts.PathFor("game"), size or 15, flags) end
