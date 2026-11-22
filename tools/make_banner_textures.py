"""Builds the success banner textures (not shipped): Media/Banner.tga, BannerLine.tga, BannerGlow.tga.
Band: dark, half transparent, fading out to the left/right and top/bottom (Banner v2 mockup).
Run from the repository root: python3 tools/make_banner_textures.py
"""
import math
from PIL import Image

def save(img, path):
    img.save(path, compression=None)
    print("wrote", path, img.size)

def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)

# band 512x128: alpha = horizontal fade * vertical fade
w, h = 512, 128
band = Image.new("RGBA", (w, h))
px = band.load()
for y in range(h):
    v = 1 - abs((y + 0.5) / h * 2 - 1)          # 0 at edges, 1 in the middle
    va = smooth(v / 0.55)
    for x in range(w):
        u = 1 - abs((x + 0.5) / w * 2 - 1)
        ua = smooth(u / 0.45)
        a = int(255 * 0.82 * ua * va)
        px[x, y] = (12, 9, 6, a)
save(band, "Media/Banner.tga")

# gold hairline 512x8: bright in the middle, fading to the ends, 2 px core + soft edge
w, h = 512, 8
line = Image.new("RGBA", (w, h))
px = line.load()
for y in range(h):
    d = abs((y + 0.5) - h / 2)
    va = 1.0 if d <= 1 else max(0.0, 1 - (d - 1) / 2.5) * 0.35
    for x in range(w):
        u = 1 - abs((x + 0.5) / w * 2 - 1)
        ua = smooth(u / 0.7)
        px[x, y] = (255, 205, 90, int(255 * ua * va))
save(line, "Media/BannerLine.tga")

# soft golden glow 256x64 behind the title
w, h = 256, 64
glow = Image.new("RGBA", (w, h))
px = glow.load()
for y in range(h):
    for x in range(w):
        dx = ((x + 0.5) / w * 2 - 1)
        dy = ((y + 0.5) / h * 2 - 1)
        r = math.sqrt(dx * dx + dy * dy)
        a = smooth(1 - r) ** 1.6
        px[x, y] = (255, 190, 60, int(255 * 0.55 * a))
save(glow, "Media/BannerGlow.tga")
