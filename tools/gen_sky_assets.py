"""gen_sky_assets.py — gera src/shared/SkyAssets.lua a partir de assets/sky/*/sky.json.

Só entram céus com as 6 faces enviadas (ids completos). Rode depois de tools/upload_sky.py.
Uso: python -I tools/gen_sky_assets.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FACES = ["Bk", "Dn", "Ft", "Lf", "Rt", "Up"]


def main():
    lines = [
        "--!strict",
        "-- SkyAssets — GERADO por tools/gen_sky_assets.py a partir de assets/sky/*/sky.json. Não editar à mão.",
        "-- Céus de 6 faces enviados ao Roblox (HDRI CC0 do Poly Haven, recoloridos). Sem entrada = céu padrão.",
        "export type SkyFaces = { Bk: string, Dn: string, Ft: string, Lf: string, Rt: string, Up: string }",
        "",
        "local SkyAssets: { [string]: SkyFaces } = {",
    ]
    count = 0
    for meta_path in sorted((ROOT / "assets" / "sky").glob("*/sky.json")):
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        ids = meta.get("ids") or {}
        if not all(ids.get(f) for f in FACES):
            print(f"{meta_path.parent.name}: faces sem ID, ignorado")
            continue
        body = ", ".join(f'{f} = "{ids[f]}"' for f in FACES)
        lines.append(f"\t-- {meta['source']} ({meta['license']}), {meta['url']}")
        lines.append(f'\t["{meta_path.parent.name}"] = {{ {body} }},')
        count += 1
    lines += ["}", "", "return SkyAssets", ""]
    out = ROOT / "src" / "shared" / "SkyAssets.lua"
    out.write_bytes("\n".join(lines).encode("utf-8"))
    print(f"SkyAssets.lua: {count} céu(s)")


if __name__ == "__main__":
    main()
