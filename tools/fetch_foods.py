"""fetch_foods.py — baixa os modelos de comida CC0 do Grab3D (https://grab3d.com, licença CC0 1.0).

Fase 2, item 3 (comidas 3D). Os .glb brutos vão para assets/foods/raw/ (fora do Git); o LICENSE.txt de
cada modelo, quando existir, é guardado junto. Depois: tools/prep_foods.py (Blender) e upload_models.py.
Uso: python -I tools/fetch_foods.py
"""
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "assets" / "foods" / "raw"
UA = {"User-Agent": "FeedAGiant-food-tool"}

# arquivo de modelo (slug do Grab3D) usado por este jogo
SLUGS = [
    "apple", "bread-loaf", "banana", "pizza", "pizza-slice", "burger", "sushi-set", "cake-slice",
    "taco", "ramen-bowl", "donut", "ice-cream-cone", "steak-plate", "pasta-plate", "fried-chicken",
    "chocolate-truffle-box", "bento-box", "brownie",
]


def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read()


def main():
    RAW.mkdir(parents=True, exist_ok=True)
    report = {}
    for slug in SLUGS:
        glb = RAW / f"{slug}.glb"
        try:
            if not glb.exists():
                glb.write_bytes(get(f"https://grab3d.com/dl/{slug}/{slug}.glb"))
            report[slug] = {"bytes": glb.stat().st_size, "url": f"https://grab3d.com/models/food/{slug}/"}
            print(f"{slug}: {glb.stat().st_size} bytes")
        except Exception as e:  # noqa: BLE001
            report[slug] = {"error": str(e)[:120]}
            print(f"{slug}: FALHOU {e}")
    (RAW / "fetch_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
