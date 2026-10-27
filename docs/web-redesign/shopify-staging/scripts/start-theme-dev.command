#!/bin/zsh
# Proxy local autenticado hacia el tema BORRADOR de staging (solo ese ID).
# La CLI pedirá "Enter your store password": escríbela aquí; no se comparte con nadie más.
# Las rutas salen de la ubicación de este archivo: sincroniza el storefront-theme/ de SU checkout (THEME.env).
HERE=${0:A:h}
ROOT=${HERE:h:h:h:h}
source "$HERE/../THEME.env"
cd "$ROOT" || exit 1
echo "Tienda: $STORE · tema borrador: $THEME_ID · proxy: http://127.0.0.1:9292"
echo "Carpeta del tema: $THEME_DIR"
echo "Deja esta ventana abierta mientras se hacen las pruebas."
exec shopify theme dev --store "$STORE" --theme "$THEME_ID" --path "$THEME_DIR" --port 9292 --live-reload off
