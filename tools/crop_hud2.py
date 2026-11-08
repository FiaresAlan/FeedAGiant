"""crop_hud2.py — recorta peças da HUD nova de referência do usuário
(assets/HUD nova referencia/feedagiant_hud_transparente.png) em PNGs individuais em assets/ui/hud2/.
Ícones dos botões: recorta o quadrado do botão, separa o desenho do fundo colorido (preenchimento a
partir da borda com tolerância de cor) e corta a legenda (o texto é desenhado pelo Roblox, traduzível).
Uso: python -I tools/crop_hud2.py   (depois: python -I tools/upload_ui.py envia assets/ui/extra)
"""
from collections import deque
from pathlib import Path
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "HUD nova referencia" / "feedagiant_hud_transparente.png"
OUT = ROOT / "assets" / "ui" / "extra"

TILES = {
    "hud2_shop": (16, 313, 120, 422),
    "hud2_arena": (127, 313, 231, 422),
    "hud2_items": (16, 428, 120, 537),
    "hud2_codes": (127, 428, 231, 537),
    "hud2_rebirth": (16, 543, 120, 652),
    "hud2_collection": (127, 543, 231, 652),
    "hud2_daily": (16, 657, 120, 766),
}
PLAIN = {  # peças sem fundo para remover (já transparentes no PNG)
    "hud2_logo": (40, 0, 262, 78),
    "hud2_coins": (26, 88, 100, 162),
    "hud2_crown": (24, 182, 74, 232),
    "hud2_mood": (28, 248, 68, 288),
    "hud2_fistglove": (1192, 890, 1298, 1004),
}


def key_out(img: Image.Image, tol: int = 75) -> Image.Image:
    """Torna transparente o fundo ligado à borda do recorte. Cada pixel é comparado com a cor do
    fundo NA MESMA LINHA (o fundo do botão é um degradê de cima para baixo), não com o vizinho: assim o
    preenchimento para no contorno escuro do desenho em vez de "vazar" para dentro dele."""
    img = img.copy()
    px = img.load()
    w, h = img.size
    ref = []
    for y in range(h):
        row = [px[x, y] for x in (0, 1, 2, w - 3, w - 2, w - 1)]
        row.sort(key=lambda c: c[0] + c[1] + c[2])
        ref.append(row[len(row) // 2])
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))

    def is_bg(c, y):
        r = ref[y]
        return c[3] < 30 or sum(abs(c[i] - r[i]) for i in range(3)) <= tol

    while q:
        x, y = q.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        c = px[x, y]
        if not is_bg(c, y):
            continue
        px[x, y] = (c[0], c[1], c[2], 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                q.append((nx, ny))
    return img


def main():
    im = Image.open(SRC).convert("RGBA")
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (x0, y0, x1, y1) in TILES.items():
        tile = im.crop((x0, y0, x1, y1))
        w, h = tile.size
        # Só a parte do desenho (sem a legenda), com uma margem para dentro da borda escura do botão.
        icon = tile.crop((9, 9, w - 9, int(h * 0.67)))
        icon = key_out(icon, 100)
        bbox = icon.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
        if bbox:
            icon = icon.crop(bbox)
        icon = icon.resize((icon.width * 3, icon.height * 3), Image.LANCZOS)
        icon.save(OUT / f"{name}.png")
        print(name, icon.size)
    for name, box in PLAIN.items():
        piece = key_out(im.crop(box), 60) if name != "hud2_logo" else im.crop(box)
        bbox = piece.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
        if bbox:
            piece = piece.crop(bbox)
        piece = piece.resize((piece.width * 3, piece.height * 3), Image.LANCZOS)
        piece.save(OUT / f"{name}.png")
        print(name, piece.size)


if __name__ == "__main__":
    main()
