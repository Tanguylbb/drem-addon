#!/usr/bin/env bash
# Test croisé add-on (Lua) <-> site (PHP) sur le format DR2.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
lua5.1 tests/interop/export.lua > "$tmp/jeu.txt"
php tests/interop/check.php "$tmp/jeu.txt" "$tmp/site.txt"
lua5.1 tests/interop/import.lua "$tmp/site.txt"
