# CurseForge gallery (1920x1080) from Felix's screenshots (/recap shot, English client, 24.11.2026).
# The screenshot paths point to the session uploads; swap them for new screenshots.
from PIL import Image, ImageFilter, ImageDraw, ImageFont, ImageEnhance
U = "/mnt/user-data/uploads/"
F = "/home/claude/RunRecap/Media/Fonts/"
W, H = 1920, 1080
HEAD = ImageFont.truetype(F + "Cinzel-Bold.ttf", 60)
SUB = ImageFont.truetype(F + "NotoSans-Regular.ttf", 30)
GOLD, LIGHT = (255, 209, 0), (232, 226, 214)

def background(img):
    bg = img.copy().convert("RGB")
    s = max(W / bg.width, H / bg.height)
    bg = bg.resize((int(bg.width * s) + 1, int(bg.height * s) + 1), Image.LANCZOS)
    x, y = (bg.width - W) // 2, (bg.height - H) // 2
    bg = bg.crop((x, y, x + W, y + H)).filter(ImageFilter.GaussianBlur(28))
    return ImageEnhance.Brightness(bg).enhance(0.45)

def text_center(d, y, text, font, fill):
    w = d.textlength(text, font=font)
    d.text(((W - w) / 2 + 2, y + 2), text, font=font, fill=(0, 0, 0))
    d.text(((W - w) / 2, y), text, font=font, fill=fill)

def slide(name, src, crop, head, sub, top=190, bottom=40):
    img = Image.open(U + src).convert("RGB")
    if crop: img = img.crop(crop)
    canvas = background(img)
    d = ImageDraw.Draw(canvas)
    text_center(d, 34, head, HEAD, GOLD)
    text_center(d, 116, sub, SUB, LIGHT)
    maxw, maxh = W - 120, H - top - bottom
    s = min(maxw / img.width, maxh / img.height)
    shot = img.resize((int(img.width * s), int(img.height * s)), Image.LANCZOS)
    x, y = (W - shot.width) // 2, top + (maxh - shot.height) // 2
    shadow = Image.new("RGBA", (shot.width + 60, shot.height + 60), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rectangle((30, 30, shot.width + 30, shot.height + 30), fill=(0, 0, 0, 200))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas.paste(shadow, (x - 30, y - 22), shadow)
    canvas.paste(shot, (x, y))
    canvas.save(f"/home/claude/gallery/{name}.png", optimize=True)

# 1: banner, full-bleed (no frame), claim on top
img = Image.open(U + "f70ad97a-image.png").convert("RGB")
img = img.crop((520, 380, 2280, 1370))  # 16:9, without quest tracker and unit frame
img = img.resize((W, H), Image.LANCZOS)
d = ImageDraw.Draw(img)
grad = Image.new("L", (1, 260))
for i in range(260): grad.putpixel((0, i), int(200 * (1 - i / 260)))
dark = Image.new("RGB", (W, 260), (0, 0, 0))
img.paste(dark, (0, 0), grad.resize((W, 260)))
d = ImageDraw.Draw(img)
text_center(d, 40, "Run Recap Forever", HEAD, GOLD)
text_center(d, 122, "Your dungeon run at a glance – right after the last boss", SUB, LIGHT)
img.save("/home/claude/gallery/1-banner.png", optimize=True)

slide("2-recap", "693f4d72-image.png", None, "Every boss. Every drop.",
      "Kill time, fight length and who got what – plus your gold, deaths and highlights")
slide("3-item", "10f4cccd-image.png", (40, 200, 1105, 1100), "Where did it drop?",
      "Hover an item: who looted it and which boss it came from")
slide("4-rolls", "a3aefdff-image.png", (95, 235, 1640, 940), "Every roll",
      "Hold Shift on a looter to see need, greed and every number")
slide("5-boss", "36fc2053-image.png", (55, 215, 1590, 925), "Boss details",
      "Hold Shift on a boss: kill time, fight length, wipes and deaths")
slide("6-skin", "f34ff665-image.png", None, "Two looks",
      "Native Blizzard style or Run Recap's dark & gold")
