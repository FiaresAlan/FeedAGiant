"""upload_models.py — envia os modelos otimizados (assets/optimized/*.glb) para o Roblox como Model.

Usa a rotina de upload do kit make-map do fwjelaa (Open Cloud, assets/v1) e a chave da variável
ROBLOX_API_KEY (ou ~/.fwjelaa/roblox-open-cloud.key). A chave NUNCA é impressa nem gravada aqui.
Os IDs vão para assets/optimized/assets.json; o que já tem ID é pulado (rode de novo sem medo).

Uso: python -I tools/upload_models.py [nome ...]      (sem nomes: todos os .glb)
Autorização de upload: dada pelo usuário em 07/11/2026 ("pode seguir, tem total aprovação").
"""
import json
import sys
import urllib.request
from pathlib import Path

KIT = Path(r"C:\Users\Administrador\Desktop\Roblox Claude Work\fwjelaa-vault-0.1.0\fwjelaa\skills\make-map\kit\tools")
sys.path.insert(0, str(KIT))
import keyfile  # noqa: E402
import upload  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OPT = ROOT / "assets" / "optimized"
MANIFEST = OPT / "assets.json"
# --foods: envia as comidas (assets/foods/optimized; autorização do usuário em 08/11/2026:
# "sobre as imagens de agora e as próximas pode enviar eu permito" + comidas 3D do Grab3D)
if "--foods" in sys.argv:
    sys.argv.remove("--foods")
    OPT = ROOT / "assets" / "foods" / "optimized"
    MANIFEST = OPT / "assets.json"


def owner_id(key):
    req = urllib.request.Request("https://apis.roblox.com/api-keys/v1/introspect",
                                 data=json.dumps({"apiKey": key}).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    info = json.load(urllib.request.urlopen(req, timeout=20))
    return info["authorizedUserId"]


def send_model(path, key, uid):
    """Igual ao upload.upload_file do kit, mas com nome e descrição deste jogo."""
    import time
    req = {"assetType": "Model", "displayName": f"FeedAGiant {path.stem}"[:50],
           "description": "Feed a Giant: criatura/marco otimizado (fontes CC0 e do autor)",
           "creationContext": {"creator": {"userId": str(uid)}}}
    body, ctype = upload.multipart(req, path.name, path.read_bytes(), "model/gltf-binary")
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


def main(names):
    key = keyfile.find_key()
    if not key:
        raise SystemExit("sem chave da Open Cloud (ROBLOX_API_KEY)")
    uid = owner_id(key)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    files = sorted(OPT.glob("*.glb"))
    if names:
        files = [f for f in files if f.stem in names]
    for f in files:
        entry = manifest.get(f.stem, {})
        # Reenvia quando o arquivo mudou (ex.: rebake de 08/11 do troll, hidra e fênix).
        if entry.get("id") and entry.get("bytes") in (None, f.stat().st_size):
            print(f"{f.stem}: já enviado ({manifest[f.stem]['id']})")
            continue
        aid = send_model(f, key, uid)
        manifest[f.stem] = {"id": aid, "file": f.name, "bytes": f.stat().st_size}
        MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"{f.stem}: {aid}")


if __name__ == "__main__":
    main(sys.argv[1:])
