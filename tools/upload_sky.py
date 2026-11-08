"""upload_sky.py — envia as 6 faces de um céu (assets/sky/<nome>/*.png) para o Roblox como Image.

Mesma rotina de upload do kit make-map do fwjelaa (Open Cloud, assets/v1) e a chave da variável
ROBLOX_API_KEY. A chave NUNCA é impressa nem gravada aqui.
Os IDs vão para assets/sky/<nome>/sky.json ("ids"); faces que já têm ID são puladas.

Uso: python -I tools/upload_sky.py <nome>
Autorização: o usuário autorizou o envio de imagens para o visual da Fase 1 (itens A–C do handoff).
"""
import json
import sys
import time
from pathlib import Path

KIT = Path(r"C:\Users\Administrador\Desktop\Roblox Claude Work\fwjelaa-vault-0.1.0\fwjelaa\skills\make-map\kit\tools")
sys.path.insert(0, str(KIT))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import keyfile  # noqa: E402
import upload  # noqa: E402
from upload_models import owner_id  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
FACES = ["Bk", "Dn", "Ft", "Lf", "Rt", "Up"]


def send_image(path, label, key, uid):
    req = {"assetType": "Image", "displayName": label[:50],
           "description": "Feed a Giant: face do céu de fim de tarde (HDRI CC0 do Poly Haven, recolorido)",
           "creationContext": {"creator": {"userId": str(uid)}}}
    body, ctype = upload.multipart(req, path.name, path.read_bytes(), "image/png")
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


def main(name):
    folder = ROOT / "assets" / "sky" / name
    meta_path = folder / "sky.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    key = keyfile.find_key()
    if not key:
        raise SystemExit("sem chave da Open Cloud (ROBLOX_API_KEY)")
    uid = owner_id(key)
    ids = meta.setdefault("ids", {})
    for face in FACES:
        if ids.get(face):
            print(f"{face}: já enviado ({ids[face]})")
            continue
        ids[face] = send_image(folder / f"{face}.png", f"FeedAGiant sky {name} {face}", key, uid)
        meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"{face}: {ids[face]}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("uso: python -I tools/upload_sky.py <nome>")
    main(sys.argv[1])
