"""make_sky.py — transforma um HDRI CC0 do Poly Haven nas 6 faces do Sky do Roblox (Fase 1, item A).

Reaproveita a geometria medida do kit make-map do fwjelaa (sky.py: orientação das faces e
detecção do sol), mas grava TUDO dentro deste projeto (o pack do fwjelaa é somente leitura).

Uso:
  python -I tools/make_sky.py <nome> --from <hdri_id> --azimuth <graus> [--size 512] [--warm 0.15]

  --azimuth  para onde o sol do céu deve apontar (graus a partir do norte -Z em direção ao leste +X);
             use o azimute do sol da receita de luz (medido no Studio com Lighting:GetSunDirection()).
  --size     512 (medido pelo kit: faces de 1024 carregam como imagem mas não renderizam como céu).
  --warm     leve correção quente/pintada (0 = foto original). Mantém o estilo cartoon do jogo.

Saída: assets/sky/<nome>/{Bk,Dn,Ft,Lf,Rt,Up}.png + sky.json (fonte, licença, sol, yaw).
Upload: python -I tools/upload_sky.py <nome>   (exige autorização do usuário).
"""
import argparse
import json
import math
import sys
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance

KIT = Path(r"C:\Users\Administrador\Desktop\Roblox Claude Work\fwjelaa-vault-0.1.0\fwjelaa\skills\make-map\kit\tools")
sys.path.insert(0, str(KIT))
import sky  # noqa: E402  (só funções puras; nada é gravado no pack)

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sky"
CACHE = ROOT / "assets" / "sky" / "_cache"  # panoramas baixados (fora do Git)
UA = {"User-Agent": "FeedAGiant-sky-tool"}


def http_json(url):
    return json.load(urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60))


def fetch_pano(asset):
    CACHE.mkdir(parents=True, exist_ok=True)
    jpg = CACHE / f"{asset}.jpg"
    if not jpg.exists():
        files = http_json(f"https://api.polyhaven.com/files/{asset}")
        url = files.get("tonemapped", {}).get("url")
        if not url:
            raise SystemExit(f"{asset} não tem JPG tonemapped no Poly Haven")
        jpg.write_bytes(urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=180).read())
    Image.MAX_IMAGE_PIXELS = None
    return Image.open(jpg).convert("RGB")


# Degradê pintado de fim de tarde por elevação (graus) -> cor (0..1). Paleta do jogo (GAME_BRIEF §5):
# horizonte dourado, coral, lilás e um azul-lavanda suave no topo (nunca o "azul de meio-dia").
PAINT = [
    (-90, (0.42, 0.40, 0.58)),
    (-5, (0.86, 0.66, 0.55)),
    (0, (1.00, 0.78, 0.48)),
    (6, (1.00, 0.70, 0.50)),
    (18, (0.96, 0.62, 0.58)),
    (40, (0.76, 0.62, 0.80)),
    (70, (0.58, 0.60, 0.84)),
    (90, (0.52, 0.58, 0.86)),
]


def _paint_rows(h):
    lat = 90 - (np.arange(h) + 0.5) / h * 180  # linha 0 = zênite
    xs = np.array([p[0] for p in PAINT], dtype=np.float32)
    cols = np.array([p[1] for p in PAINT], dtype=np.float32)
    return np.stack([np.interp(lat, xs, cols[:, c]) for c in range(3)], axis=1)  # (h, 3)


def warm_grade(im, amount):
    """Recolore o panorama com o degradê pintado, preservando o brilho da foto (nuvens, sol).

    amount 0 = foto original; 1 = só a cor do degradê (com o brilho da foto)."""
    if amount <= 0:
        return im
    a = np.asarray(im, dtype=np.float32) / 255.0
    h = a.shape[0]
    paint = _paint_rows(h)[:, None, :]  # (h, 1, 3)
    lum = (a * np.array([0.299, 0.587, 0.114], dtype=np.float32)).sum(axis=2, keepdims=True)
    plum = (paint * np.array([0.299, 0.587, 0.114], dtype=np.float32)).sum(axis=2, keepdims=True)
    recolored = paint * (lum / np.maximum(plum, 1e-3))
    # O sol e os realces muito claros mantêm a cor quente original (senão o sol fica cinza).
    keep = np.clip((lum - 0.80) / 0.15, 0, 1)
    k = amount * (1 - keep)
    out = a * (1 - k) + recolored * k
    out = Image.fromarray(np.clip(out * 255, 0, 255).astype(np.uint8))
    out = ImageEnhance.Color(out).enhance(1.3)
    out = ImageEnhance.Brightness(out).enhance(1.08)
    return ImageEnhance.Contrast(out).enhance(1.05)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("--from", dest="source", required=True, help="id do HDRI no Poly Haven (ex.: qwantani_sunset_puresky)")
    ap.add_argument("--azimuth", type=float, required=True)
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--warm", type=float, default=0.15)
    a = ap.parse_args()

    pano = fetch_pano(a.source)
    sun = sky.sun_direction(pano)
    yaw = sky.yaw_for(sun, a.azimuth)
    graded = warm_grade(pano.resize((4096, 2048), Image.LANCZOS), a.warm)
    faces = sky.cube_faces(graded, size=a.size, yaw_deg=yaw)
    out = OUT / a.name
    out.mkdir(parents=True, exist_ok=True)
    for k, im in faces.items():
        im.save(out / f"{k}.png", optimize=True)
    final = sky.rotate_dir(sun, -yaw)
    meta = {
        "source": f"polyhaven:{a.source}",
        "url": f"https://polyhaven.com/a/{a.source}",
        "license": "CC0 1.0",
        "sun_dir": [round(c, 4) for c in final],
        "sun_elevation_deg": round(math.degrees(math.asin(final[1])), 2),
        "yaw": round(yaw, 2),
        "size": a.size,
        "warm": a.warm,
        "remake": f"python -I tools/make_sky.py {a.name} --from {a.source} --azimuth {a.azimuth:g} --size {a.size} --warm {a.warm:g}",
    }
    old = out / "sky.json"
    if old.exists():  # preserva IDs já enviados só se as imagens não mudaram de receita
        prev = json.loads(old.read_text(encoding="utf-8"))
        if prev.get("remake") == meta["remake"] and prev.get("ids"):
            meta["ids"] = prev["ids"]
    old.write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(meta, ensure_ascii=False))


if __name__ == "__main__":
    main()
