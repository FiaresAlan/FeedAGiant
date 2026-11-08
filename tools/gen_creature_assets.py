"""gen_creature_assets.py — gera src/shared/CreatureAssets.lua a partir de assets/optimized/assets.json.

Rode depois de tools/upload_models.py. Sem IDs, o arquivo sai vazio e o jogo usa os corpos de blocos.
Uso: python -I tools/gen_creature_assets.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest_path = ROOT / "assets" / "optimized" / "assets.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
lines = [
    "--!strict",
    "-- CreatureAssets — GERADO por tools/gen_creature_assets.py a partir de assets/optimized/assets.json.",
    "-- Não editar à mão. Chave = nome do .glb em assets/optimized; valor = rbxassetid do Model enviado.",
    "return {",
]
for name in sorted(manifest):
    aid = manifest[name].get("id")
    if aid:
        lines.append(f'\t["{name}"] = "{aid}",')
lines.append("} :: { [string]: string }")
out = ROOT / "src" / "shared" / "CreatureAssets.lua"
out.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
print(f"{out.relative_to(ROOT)}: {sum(1 for n in manifest if manifest[n].get('id'))} IDs")
