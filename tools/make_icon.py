"""Builds the addon icon (minimap button, window portrait, addon list): Media/Icon.tga.
Source: docs/curseforge/icon.svg (the logo without its frame, on a round dark background).
Needs rsvg-convert and Pillow. Run from the repository root: python3 tools/make_icon.py"""
import subprocess
import tempfile
from PIL import Image

with tempfile.NamedTemporaryFile(suffix=".png") as tmp:
    subprocess.run(["rsvg-convert", "-w", "128", "-h", "128", "docs/curseforge/icon.svg", "-o", tmp.name], check=True)
    Image.open(tmp.name).convert("RGBA").save("Media/Icon.tga", compression=None)
