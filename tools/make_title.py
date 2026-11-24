# CurseForge title image (1920x1080): logo, name, claim and the recap window from the Kral run.
# The screenshot paths point to the session uploads; swap them for new screenshots.
from PIL import Image, ImageFilter, ImageDraw, ImageFont, ImageEnhance
U = "/mnt/user-data/uploads/"; F = "/home/claude/RunRecap/Media/Fonts/"
W, H = 1920, 1080
bg = Image.open(U + "f70ad97a-image.png").convert("RGB").crop((300, 0, 1400, 619)).resize((W, H), Image.LANCZOS)
bg = ImageEnhance.Brightness(bg.filter(ImageFilter.GaussianBlur(14))).enhance(0.42)
# darker on the left for the text
shade = Image.new("L", (W, 1))
for x in range(W): shade.putpixel((x, 0), int(max(0, 170 * (1 - x / 1100))))
bg.paste(Image.new("RGB", (W, H), (0, 0, 0)), (0, 0), shade.resize((W, H)))
d = ImageDraw.Draw(bg)

logo = Image.open("/home/claude/RunRecap/docs/curseforge/logo-1024.png").convert("RGBA").resize((300, 300), Image.LANCZOS)
bg.paste(logo, (110, 150), logo)

def t(xy, text, font, fill):
    d.text((xy[0] + 3, xy[1] + 3), text, font=font, fill=(0, 0, 0))
    d.text(xy, text, font=font, fill=fill)

title = ImageFont.truetype(F + "Cinzel-Bold.ttf", 92)
claim = ImageFont.truetype(F + "NotoSans-Regular.ttf", 40)
small = ImageFont.truetype(F + "NotoSans-Regular.ttf", 30)
GOLD, LIGHT, GREY = (255, 209, 0), (236, 230, 218), (190, 180, 160)
t((110, 500), "Run Recap", title, GOLD)
t((110, 600), "Forever", title, GOLD)
t((112, 740), "Every run deserves a proper finish", claim, LIGHT)
y = 820
for line in ("Victory banner and sound after the last boss", "Every boss, every drop, every roll", "Deaths, highlights and your gold"):
    d.ellipse((116, y + 14, 128, y + 26), fill=GOLD)
    t((146, y), line, small, GREY)
    y += 48

src = Image.open(U + "693f4d72-image.png").convert("RGB")
X0, Y0, X1, Y1 = 105, 66, 1690, 1482
shot = src.crop((X0, Y0, X1, Y1))
# window frame + round portrait, without the game world in the corners
mask = Image.new("L", shot.size, 0)
md = ImageDraw.Draw(mask)
md.rectangle((122 - X0, 84 - Y0, X1 - X0, Y1 - Y0), fill=255)
md.ellipse((110 - X0, 70 - Y0, 250 - X0, 210 - Y0), fill=255)
s = 880 / shot.height
size = (int(shot.width * s), 880)
shot, mask = shot.resize(size, Image.LANCZOS), mask.resize(size, Image.LANCZOS)
x, yy = W - shot.width - 90, (H - shot.height) // 2
sh = Image.new("RGBA", (shot.width + 80, shot.height + 80), (0, 0, 0, 0))
shm = Image.new("L", sh.size, 0); shm.paste(mask, (40, 40))
sh.putalpha(shm.point(lambda v: int(v * 0.85)))
sh = sh.filter(ImageFilter.GaussianBlur(24))
bg.paste(sh, (x - 40, yy - 28), sh)
bg.paste(shot, (x, yy), mask)
bg.save("/home/claude/gallery/0-title.png", optimize=True)
