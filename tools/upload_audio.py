"""upload_audio.py — envia os sons aprovados (assets/audio/*.wav e *.mp3) como Audio e gera
src/shared/AudioAssets.lua (nome do arquivo sem extensão -> rbxassetid).

IDs guardados em assets/audio/audio_assets.json; o que já tem ID (e não mudou de tamanho) é pulado.
Chave: ROBLOX_API_KEY (nunca impressa). Autorização do usuário (08/11/2026): "pode usar esses e
substituir o que já temos, todos esses áudios estão aprovados" + autorização total da API Key.
Uso: python -I tools/upload_audio.py
"""
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from upload_sky import keyfile, upload  # noqa: E402
from upload_models import owner_id  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
MANIFEST = AUDIO / "audio_assets.json"
CTYPE = {".wav": "audio/wav", ".mp3": "audio/mpeg", ".ogg": "audio/ogg"}


def send_audio(path, key, uid):
    req = {"assetType": "Audio", "displayName": f"FeedAGiant {path.stem}"[:50],
           "description": "Feed a Giant: efeito sonoro / narrador do jogo",
           "creationContext": {"creator": {"userId": str(uid)}}}
    body, ctype = upload.multipart(req, path.name, path.read_bytes(), CTYPE[path.suffix.lower()])
    headers = {"x-api-key": key}
    op = upload._post(f"{upload.API}/assets", body, {**headers, "Content-Type": ctype})
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(90):
        if op.get("done"):
            if "response" not in op:
                raise RuntimeError(f"upload de {path.name} falhou: {op.get('error')}")
            return "rbxassetid://" + str(op["response"]["assetId"])
        time.sleep(2)
        op = upload._poll(f"{upload.API}/operations/{op_id}", headers)
    raise TimeoutError(f"upload de {path.name} não terminou")


def main():
    files = sorted(p for p in AUDIO.iterdir() if p.suffix.lower() in CTYPE)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    key = keyfile.find_key()
    if not key:
        raise SystemExit("sem chave da Open Cloud (ROBLOX_API_KEY)")
    uid = owner_id(key)
    for f in files:
        name = f.stem
        entry = manifest.get(name)
        if entry and entry.get("id") and entry.get("bytes") == f.stat().st_size:
            print(f"{name}: já enviado ({entry['id']})")
            continue
        try:
            aid = send_audio(f, key, uid)
        except Exception as e:  # um arquivo recusado não para os outros
            print(f"{name}: FALHOU {e}")
            continue
        manifest[name] = {"id": aid, "bytes": f.stat().st_size}
        MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"{name}: {aid}")
    lines = [
        "--!strict",
        "-- AudioAssets — GERADO por tools/upload_audio.py a partir de assets/audio/audio_assets.json.",
        "-- Não editar à mão. Sons aprovados pelo usuário em 08/11/2026.",
        "return {",
    ]
    for name in sorted(manifest):
        lines.append(f'\t["{name}"] = "{manifest[name]["id"]}",')
    lines.append("} :: { [string]: string }")
    (ROOT / "src" / "shared" / "AudioAssets.lua").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"AudioAssets.lua: {len(manifest)} sons")


if __name__ == "__main__":
    main()
