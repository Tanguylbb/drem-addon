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
lua5.1 tests/preview.lua "$OUT" > /dev/null
NODE_PATH="${NODE_PATH:-$(npm root -g)}" node tests/preview/render.js "$OUT" DernierRempart/Media
