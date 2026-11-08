"""prep_foods.py — otimiza as comidas CC0 do Grab3D para o Roblox (Fase 2, item 3).

Para cada entrada de FOODS roda o pipeline Blender (tools/blender/prep_creature.py) com:
  * no máximo TRIS triângulos (orçamento: até 128 comidas visíveis = 16 vagas x 8 bases;
    vault "Art Budgets": prop pequeno 100-800, médio 800-3k);
  * textura de cor de 512 px;
  * a MAIOR dimensão = FIT studs (--fit), pé em Z = 0.
Saída: assets/foods/optimized/<arquivo>.glb + previews/<arquivo>.png. Upload: upload_models.py --dir foods.
Uso: python -I tools/prep_foods.py [slug ...]
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "assets" / "foods" / "raw"
OPT = ROOT / "assets" / "foods" / "optimized"
BLENDER = r"C:\Users\Administrador\Desktop\blender-5.4.0-alpha+main.50d477803fa8-windows.amd64-release\blender.exe"
SCRIPT = ROOT / "tools" / "blender" / "prep_creature.py"

TRIS = 1200
# slug do Grab3D -> tamanho (maior dimensão, studs). Pátio: vagas de 6x6 studs.
FOODS = {
    "apple": 3.0,
    "bread-loaf": 4.0,
    "banana": 4.0,
    "pizza": 4.6,
    "burger": 3.6,
    "sushi-set": 4.6,
    "cake-slice": 3.6,
    "taco": 4.0,
    "ramen-bowl": 4.2,
    "donut": 3.6,
    "ice-cream-cone": 4.0,
    "steak-plate": 4.6,
    "pasta-plate": 4.6,
    "fried-chicken": 4.0,
    "chocolate-truffle-box": 4.4,
    "bento-box": 4.4,
}


def main(only):
    (OPT / "previews").mkdir(parents=True, exist_ok=True)
    for slug, fit in FOODS.items():
        if only and slug not in only:
            continue
        src = RAW / f"{slug}.glb"
        out = OPT / f"food-{slug}.glb"
        png = OPT / "previews" / f"food-{slug}.png"
        cmd = [BLENDER, "-b", "--factory-startup", "-P", str(SCRIPT), "--", str(src), str(out), str(png),
               "--tris", str(TRIS), "--fit", str(fit), "--tex", "512"]
        r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
        tail = [l for l in r.stdout.splitlines() if "tris" in l.lower() or "studs" in l.lower() or "erro" in l.lower()]
        print(f"{slug}: exit {r.returncode} {' | '.join(tail[-2:])}")
        if r.returncode != 0:
            print(r.stderr[-800:])


if __name__ == "__main__":
    main(sys.argv[1:])
