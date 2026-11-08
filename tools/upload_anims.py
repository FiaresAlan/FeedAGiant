"""upload_anims.py — envia as animações de boxe (assets/anims/*.rbxmx) como Animation e gera
src/shared/AnimationIds.lua.

As animações vêm do kit make-anim do fwjelaa (método fwjelaa / FWJ STUDIOS; ver CREDITS do pack):
  BLENDER=<blender.exe> python kit/run.py make R15_M1_1   (no pack)  -> copiar out/<nome>.rbxmx para assets/anims/
O envio usa a função upload() do próprio kit (Open Cloud aceita KeyframeSequence .rbxmx como Animation).
Chave: ROBLOX_API_KEY (nunca impressa). Dono: o usuário dono da chave.
Autorização do usuário (08/11/2026): autorização total para usar a API Key do Creator Hub.
Uso: python -I tools/upload_anims.py
"""
import importlib.util
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from upload_sky import keyfile  # noqa: E402
from upload_models import owner_id  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
ANIMS = ROOT / "assets" / "anims"
MANIFEST = ANIMS / "anims.json"
KIT_UPLOAD = Path(r"C:\Users\Administrador\Desktop\Roblox Claude Work\fwjelaa-vault-0.1.0\fwjelaa\skills\make-anim\kit\upload.py")


def kit_upload():
    spec = importlib.util.spec_from_file_location("anim_upload", KIT_UPLOAD)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.upload


def main():
    upload = kit_upload()
    key = keyfile.find_key()
    if not key:
        raise SystemExit("sem chave da Open Cloud (ROBLOX_API_KEY)")
    creator = {"userId": str(owner_id(key))}
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    for f in sorted(ANIMS.glob("*.rbxmx")):
        entry = manifest.get(f.stem)
        if entry and entry.get("id") and entry.get("bytes") == f.stat().st_size:
            print(f"{f.stem}: já enviado ({entry['id']})")
            continue
        res = upload(f, f"FeedAGiant {f.stem}", "Feed a Giant: boxe (método fwjelaa)", creator, key)
        if "assetId" not in res:
            print(f"{f.stem}: FALHOU {res}")
            continue
        manifest[f.stem] = {"id": f"rbxassetid://{res['assetId']}", "bytes": f.stat().st_size}
        MANIFEST.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        print(f"{f.stem}: {manifest[f.stem]['id']}")
    lines = [
        "--!strict",
        "-- AnimationIds — GERADO por tools/upload_anims.py (assets/anims/anims.json). Não editar à mão.",
        "-- Animações R15 de boxe feitas com o kit make-anim do fwjelaa (método fwjelaa / FWJ STUDIOS).",
        "return {",
    ]
    for name in sorted(manifest):
        lines.append(f'\t{name} = "{manifest[name]["id"]}",')
    lines.append("} :: { [string]: string }")
    (ROOT / "src" / "shared" / "AnimationIds.lua").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"AnimationIds.lua: {len(manifest)} animações")


if __name__ == "__main__":
    main()
