"""slice_icons.py — recorta a folha de ícones (assets/ui/icons_sheet.png, 1536x1024, 4x2) em 8 ícones.

Por quê: o Roblox reduz imagens enviadas para no máximo 1024 px; a folha virava 1024x683 e os recortes
ImageRectOffset/Size em pixels da folha original apontavam para o lugar errado (ícones vazios na HUD).
Cada ícone vira um PNG quadrado de 256 px em assets/ui/icons/<nome>.png (fundo escuro da arte original,
com cantos arredondados transparentes para virar "azulejo" no botão).
Uso: python -I tools/slice_icons.py   (depois: python -I tools/upload_ui.py)
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "ui" / "icons_sheet.png"
OUT = ROOT / "assets" / "ui" / "icons"
NAMES = [["coin", "glove", "lunchbox", "backpack"], ["trophy", "shield", "crown", "gear"]]
CENTERS_Y = [288, 732]  # centro visual dos ícones em cada linha (medido na arte)
CROP = 360
SIZE = 256


def main():
    sheet = Image.open(SRC).convert("RGBA")
    OUT.mkdir(parents=True, exist_ok=True)
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=48, fill=255)
    for r, row in enumerate(NAMES):
        for c, name in enumerate(row):
            cx, cy = 192 + 384 * c, CENTERS_Y[r]
            box = (cx - CROP // 2, cy - CROP // 2, cx + CROP // 2, cy + CROP // 2)
            icon = sheet.crop(box).resize((SIZE, SIZE), Image.LANCZOS)
            icon.putalpha(mask)
            icon.save(OUT / f"{name}.png", optimize=True)
            print(name, box)


if __name__ == "__main__":
    main()
