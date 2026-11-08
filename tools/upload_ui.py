"""upload_ui.py — envia as imagens da HUD (assets/ui/icons/*.png e assets/ui/extra/*.png) como Image
e gera src/shared/UIAssets.lua (nome -> rbxassetid).

IDs guardados em assets/ui/ui_assets.json; o que já tem ID (e não mudou de tamanho) é pulado.
Chave: ROBLOX_API_KEY (nunca impressa). Autorização do usuário (08/11/2026): "sobre as imagens de agora
e as próximas pode enviar eu permito".
Uso: python -I tools/upload_ui.py
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from upload_sky import send_image, keyfile  # noqa: E402
from upload_models import owner_id  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "assets" / "ui"
MANIFEST = UI / "ui_assets.json"


def main():
    files = sorted((UI / "icons").glob("*.png")) + sorted((UI / "extra").glob("*.png"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    key = keyfile.find_key()
    if not key:
        raise SystemExit("sem chave da Open Cloud (ROBLOX_API_KEY)")
    uid = owner_id(key)
    for f in files:
        name = f.stem if f.parent.name == "icons" else f"extra_{f.stem}"
        entry = manifest.get(name)
        if entry and entry.get("id") and entry.get("bytes") == f.stat().st_size:
            print(f"{name}: já enviado ({entry['id']})")
            continue
        aid = send_image(f, f"FeedAGiant ui {name}", key, uid)
        manifest[name] = {"id": aid, "file": str(f.relative_to(ROOT)).replace("\\", "/"), "bytes": f.stat().st_size}
        MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"{name}: {aid}")
    lines = [
        "--!strict",
        "-- UIAssets — GERADO por tools/upload_ui.py a partir de assets/ui/ui_assets.json. Não editar à mão.",
        "-- Ícones recortados de assets/ui/icons_sheet.png (arte do usuário) e peças extras da HUD.",
        "return {",
    ]
    for name in sorted(manifest):
        lines.append(f'\t["{name}"] = "{manifest[name]["id"]}",')
    lines.append("} :: { [string]: string }")
    (ROOT / "src" / "shared" / "UIAssets.lua").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"UIAssets.lua: {len(manifest)} imagens")


if __name__ == "__main__":
    main()
