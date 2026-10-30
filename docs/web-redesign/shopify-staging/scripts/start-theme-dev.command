#!/bin/zsh
# Proxy local autenticado hacia el tema BORRADOR de staging (solo ese ID).
# La CLI pedirá "Enter your store password": escríbela aquí; no se comparte con nadie más.
# Las rutas salen de la ubicación de este archivo: sincroniza el storefront-theme/ de SU checkout (THEME.env).
HERE=${0:A:h}
ROOT=${HERE:h:h:h:h}
source "$HERE/../THEME.env"
cd "$ROOT" || exit 1
# Never a live theme: theme dev would write every saved file straight into the published storefront. Since 28 Oct the guide
# draft is published on staging; work on a fresh unpublished duplicate and point THEME.env at it.
ROLE="$(shopify theme list --store "$STORE" --id "$THEME_ID" --json --no-color | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d[0]["role"] if d else "NONE")')"
if [ "$ROLE" != "unpublished" ]; then
  echo "ABORT: el tema $THEME_ID tiene rol '$ROLE'. Sólo se trabaja sobre un borrador sin publicar (duplica el tema y apunta THEME.env al duplicado)." >&2
  exit 2
fi
echo "Tienda: $STORE · tema borrador: $THEME_ID · proxy: http://127.0.0.1:9292"
echo "Carpeta del tema: $THEME_DIR"
echo "Deja esta ventana abierta mientras se hacen las pruebas."
exec shopify theme dev --store "$STORE" --theme "$THEME_ID" --path "$THEME_DIR" --port 9292 --live-reload off
