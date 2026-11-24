# Minimap Satchel © 2026 Ghosti. All Rights Reserved.
# Livraison : python pipeline/release.py <version>   (depuis la racine du projet)
# Lance la suite de tests (rien n'est livré si elle échoue), met la version dans le .toc
# et Core.lua, crée dist/MinimapSatchel-<v>.zip (séparateurs "/", dossier racine MinimapSatchel/),
# range les anciens MinimapSatchel-*.zip du dossier Interface de Forever dans
# Interface\_MinimapSatchel_anciennes\ (déplacés, jamais supprimés), puis y dépose le nouveau.
import os, re, shutil, subprocess, sys, zipfile

v = sys.argv[1]
if not re.fullmatch(r"\d+\.\d+\.\d+", v):
    sys.exit("version attendue : X.Y.Z")
if subprocess.run(["sh", "test/run_all.sh"], capture_output=True).returncode != 0:
    sys.exit("suite de tests en échec : rien n'est livré (sh test/run_all.sh)")

OUT = r"D:\World of Warcraft\_forever_\Interface"
OLD = os.path.join(OUT, "_MinimapSatchel_anciennes")
A = "MinimapSatchel"

def sub(path, pattern, repl):
    s = open(path, encoding="utf-8").read()
    s2, n = re.subn(pattern, repl, s)
    if n != 1:
        sys.exit(f"version introuvable dans {path}")
    open(path, "w", encoding="utf-8", newline="").write(s2)

sub(f"{A}/{A}.toc", r"(?m)^## Version: .*$", f"## Version: {v}")
sub(f"{A}/Core.lua", r'MS\.VERSION    = "[^"]*"', f'MS.VERSION    = "{v}"')

os.makedirs("dist", exist_ok=True)
zpath = f"dist/{A}-{v}.zip"
with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as zf:
    for root, _, files in os.walk(A):
        for f in files:
            p = os.path.join(root, f)
            zf.write(p, p.replace(os.sep, "/"))

os.makedirs(OLD, exist_ok=True)
for n in os.listdir(OUT):
    if re.match(rf"^{A}-\d+\.\d+\.\d+\.zip$", n):
        dst = os.path.join(OLD, n)
        k = 1
        while os.path.exists(dst):              # jamais d'écrasement dans l'archive
            dst = os.path.join(OLD, f"{n[:-4]}_{k}.zip"); k += 1
        shutil.move(os.path.join(OUT, n), dst)
shutil.copy(zpath, OUT)
print(zpath, os.path.getsize(zpath) // 1024, "KB ->", OUT)
