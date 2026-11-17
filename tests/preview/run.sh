#!/usr/bin/env bash
# Dessine l'interface hors du jeu : bash tests/preview/run.sh <dossier de sortie>
# (nécessite lua5.1, Python avec Pillow, Node avec Playwright.)
set -e
OUT="${1:-preview-out}"
mkdir -p "$OUT/media"
python3 - "$OUT" <<'PY'
import glob, os, sys
from PIL import Image
for f in glob.glob("DernierRempart/Media/*.tga"):
    Image.open(f).convert("RGBA").save(os.path.join(sys.argv[1], "media", os.path.basename(f)[:-4] + ".png"))
PY
export NODE_PATH="${NODE_PATH:-$(npm root -g)}"
# Deux passes : des noms courts, puis des noms aussi longs que dans une vraie guilde.
lua5.1 tests/preview.lua "$OUT" > /dev/null
node tests/preview/render.js "$OUT" DernierRempart/Media
mkdir -p "$OUT/long/media"
cp "$OUT"/media/* "$OUT/long/media/"
lua5.1 tests/preview.lua "$OUT/long" long > /dev/null
echo "--- noms longs ---"
node tests/preview/render.js "$OUT/long" DernierRempart/Media
