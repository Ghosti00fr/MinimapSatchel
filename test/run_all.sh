#!/bin/bash
# Lance tous les tests hors jeu depuis la racine du projet.
cd "$(dirname "$0")/.." || exit 1
LUAJIT="/c/Users/klass/AppData/Local/Programs/LuaJIT/bin/luajit.exe"
for t in test/t_*.lua; do
    echo "== $t"
    "$LUAJIT" "$t" || { echo "ÉCHEC : $t"; exit 1; }
done
echo "TOUS LES TESTS OK"
