"""gen_food_assets.py — gera src/shared/FoodAssets.lua a partir de assets/foods/optimized/assets.json.

Rode depois de `python -I tools/upload_models.py --foods`. Sem IDs, o jogo usa as formas de blocos antigas.
Uso: python -I tools/gen_food_assets.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest_path = ROOT / "assets" / "foods" / "optimized" / "assets.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
lines = [
    "--!strict",
    "-- FoodAssets — GERADO por tools/gen_food_assets.py a partir de assets/foods/optimized/assets.json.",
    "-- Não editar à mão. Chave = nome do .glb (food-<slug do Grab3D>, CC0); valor = rbxassetid do Model.",
    "return {",
]
for name in sorted(manifest):
    aid = manifest[name].get("id")
    if aid:
        lines.append(f'\t["{name}"] = "{aid}",')
lines.append("} :: { [string]: string }")
out = ROOT / "src" / "shared" / "FoodAssets.lua"
out.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
print(f"{out.relative_to(ROOT)}: {sum(1 for n in manifest if manifest[n].get('id'))} IDs")
