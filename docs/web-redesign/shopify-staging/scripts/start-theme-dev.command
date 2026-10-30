#!/bin/zsh
# Proxy local autenticado hacia el tema BORRADOR de staging (solo ese ID).
# La CLI pedirá "Enter your store password": escríbela aquí; no se comparte con nadie más.
source /Users/alexis_reyna/MyCode/Monetta/docs/web-redesign/shopify-staging/THEME.env
cd /Users/alexis_reyna/MyCode/Monetta || exit 1
echo "Tienda: $STORE · tema borrador: $THEME_ID · proxy: http://127.0.0.1:9292"
echo "Deja esta ventana abierta mientras se hacen las pruebas."
exec shopify theme dev --store "$STORE" --theme "$THEME_ID" --path "$THEME_DIR" --port 9292 --live-reload off
