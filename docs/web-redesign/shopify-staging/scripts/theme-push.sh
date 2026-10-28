#!/usr/bin/env bash
# Sube storefront-theme/ SOLO al tema borrador autorizado. Verifica tienda, ID, nombre y rol
# antes de cada subida y se niega si el rol no es "unpublished".
# Uso: theme-push.sh [--only "archivo" ...]   (los argumentos extra se pasan a `shopify theme push`)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
source "$HERE/THEME.env"
INFO="$(shopify theme list --store "$STORE" --id "$THEME_ID" --json --no-color)"
ROLE="$(printf '%s' "$INFO" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d[0]["role"] if d else "NONE")')"
NAME="$(printf '%s' "$INFO" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d[0]["name"] if d else "NONE")')"
if [ "$ROLE" != "unpublished" ] || [ "$NAME" != "$THEME_NAME" ]; then
  echo "ABORT: tema $THEME_ID en $STORE tiene rol='$ROLE' nombre='$NAME' (se esperaba unpublished / '$THEME_NAME')" >&2
  exit 2
fi
echo "OK destino: $STORE · $THEME_ID · $NAME · $ROLE · $(date -u +%FT%TZ)"
exec shopify theme push --store "$STORE" --theme "$THEME_ID" --path "$THEME_DIR" --no-color --no-input "$@"
