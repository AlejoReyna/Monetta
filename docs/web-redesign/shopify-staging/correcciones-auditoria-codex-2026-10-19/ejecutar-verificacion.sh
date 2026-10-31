#!/usr/bin/env bash
# Verificación de cierre de las correcciones de la auditoría de Codex (19/10/2026). Un solo proxy sano, comprobado con esperas acotadas
# antes de cada paso; si deja de estar sano o de servir el tema esperado, el script se detiene (no emite resultados con un proxy dudoso)
# y se reanuda con START_AT=<paso>. No sube nada al tema: solo lee la tienda de staging (los carritos de prueba son anónimos y todo se
# detiene en la entrada al checkout, sin pedidos ni pagos).
#
#   BASE=http://127.0.0.1:9292 [START_AT=layout] [ONLY=regressions,journey] docs/web-redesign/shopify-staging/correcciones-auditoria-codex-2026-10-19/ejecutar-verificacion.sh
set -u
cd "$(dirname "$0")/../../../.."
BASE="${BASE:-http://127.0.0.1:9292}"
E=docs/web-redesign/shopify-staging/scripts/e2e
S=docs/web-redesign/shopify-staging/scripts
OUT=docs/web-redesign/shopify-staging/correcciones-auditoria-codex-2026-10-19
LOG="$OUT/despues/ejecucion.log"
mkdir -p "$OUT/despues"
tree() { node --input-type=module -e "import('./$E/lib.mjs').then(m=>console.log(m.treeDigest().sha256))"; }
START_TREE="$(tree)"
echo "# $(date -u +%FT%TZ) inicio · árbol $START_TREE · base $BASE" | tee -a "$LOG"

started=${START_AT:+0}; started=${started:-1}
should_run() { # $1 = nombre del paso
  if [ -n "${ONLY:-}" ] && ! echo ",$ONLY," | grep -q ",$1,"; then return 1; fi
  if [ "$started" = 0 ]; then if [ "$1" = "$START_AT" ]; then started=1; else return 1; fi; fi
  return 0
}
healthy() { # hasta 3 intentos, cada uno con esperas acotadas dentro de proxy-health.mjs
  for i in 1 2 3; do
    if node "$E/proxy-health.mjs" "$BASE" > "$OUT/despues/proxy-salud-ultima.json"; then return 0; fi
    sleep 10
  done
  cp "$OUT/despues/proxy-salud-ultima.json" "$OUT/despues/proxy-salud-FALLO-$1.json"
  return 1
}
step() { # $1 = nombre, resto = comando
  local name="$1"; shift
  should_run "$name" || return 0
  healthy "$name" || { echo "!! $(date -u +%FT%TZ) $name: proxy no sano o no sirve el tema esperado; detenido (reanudar con START_AT=$name)" | tee -a "$LOG"; exit 2; }
  echo "== $(date -u +%FT%TZ) $name: $*" | tee -a "$LOG"
  "$@" > "$OUT/despues/salida-$name.txt" 2>&1
  local code=$?
  echo "   exit $code · $(tail -n 2 "$OUT/despues/salida-$name.txt" | head -n 1 | cut -c1-200)" | tee -a "$LOG"
}

for size in 375x812 440x956 768x1024 1024x768 1440x900 812x375; do
  w=${size%x*}; h=${size#*x}
  step "journey-$size" node "$E/journey.mjs" --base-url="$BASE" --w="$w" --h="$h"
done
for size in 375x812 440x956 768x1024 1024x768 1440x900 812x375; do
  w=${size%x*}; h=${size#*x}
  step "regressions-$size" node "$E/regressions.mjs" --base-url="$BASE" --w="$w" --h="$h"
done
step layout node "$E/layout.mjs" --base-url="$BASE"
step layout-insets node "$E/layout.mjs" --base-url="$BASE" --insets=44 --viewports=375x812,812x375,1024x200,768x1024,1440x900,1024x481
step keyboard-a node "$E/keyboard.mjs" --base-url="$BASE" --viewports=375x812,440x956,320x640
step keyboard-b node "$E/keyboard.mjs" --base-url="$BASE" --viewports=768x1024,1024x768,812x375
step keyboard-c node "$E/keyboard.mjs" --base-url="$BASE" --viewports=1440x900,1024x200,1024x480,1024x481
step keyboard-insets node "$E/keyboard.mjs" --base-url="$BASE" --insets=44 --viewports=812x375,375x812,1024x768
step nav node "$E/nav.mjs" --base-url="$BASE"
step nav-insets node "$E/nav.mjs" --base-url="$BASE" --insets=44
step axe node "$E/axe.mjs" --base-url="$BASE"
step motion node "$E/motion.mjs" --base-url="$BASE"
step screens node "$E/screens.mjs" --base-url="$BASE"
step screens-insets node "$E/screens.mjs" --base-url="$BASE" --insets=44 --viewports=812x375,375x812
for size in 375x812 768x1024 1440x900 812x375; do
  w=${size%x*}; h=${size#*x}
  step "states-$size" node "$E/states.mjs" --base-url="$BASE" --w="$w" --h="$h"
done
step states-812x375-insets node "$E/states.mjs" --base-url="$BASE" --w=812 --h=375 --insets=44
step states-375x812-insets node "$E/states.mjs" --base-url="$BASE" --w=375 --h=812 --insets=44

# Controles negativos: cada uno reintroduce un defecto auditado y debe fallar la(s) aserción(es) concreta(s) declarada(s) en --expect.
ctl() { # nombre, args del guion..., --expect=...
  local name="$1"; shift
  step "control-$name" node "$E/regressions.mjs" --base-url="$BASE" --w=1440 --h=900 --label="$name" "$@"
}
ctl p1-scripts-previos --only=p1 --old-assets=monetta-product.js,monetta-cart.js "--expect=P1 [staging] slow answer: every add button is really disabled|P1 [staging] slow answer: pressing every add button|P1 [staging] slow answer: the accelerated-checkout button (Buy it now) starts nothing|/^P1 \\[staging\\] HTTP 503: the chips, the header value, the id and the address go back/|/^P1 \\[staging\\] dropped connection: adding sends the variant shown/"
ctl p2-script-previo --only=p2 --old-assets=monetta-cart.js "--expect=/^P2 \\[staging\\] increment: while it is pending every checkout button is disabled/|/^P2 \\[staging\\] increment: \\d+ ways of submitting checkout/|/^P2 \\[staging\\] remove: \\d+ ways of submitting checkout/|/^P2 \\[staging\\] transport failure and no read-back: the bag is unconfirmed/|/^P2 \\[controlled\\] the accelerated-checkout area is inert/"
ctl p5-script-previo --only=p5 --old-assets=monetta-listing.js "--expect=/the failure box offers a retry button/|/retrying while Shopify still fails/|/HTTP 200 with a body that is not a listing/|/HTTP 200 with a password wall/|/the native link performs a real navigation/"
ctl p6-enlace-previo --only=p6 --rewrite=edit-search-href --old-assets=monetta-listing.js "--expect=/phone 375×812, mouse: the focus lands/|/phone 375×812, keyboard: the focus lands/|/phone 375×812, mouse: the link's own href/"
ctl p7-script-previo --only=p7 --old-assets=monetta-cart.js "--expect=/Deshacer restores the personalised line/|/\\[controlled\\] Deshacer re-adds with the line/|/a line whose identity cannot be read offers no Deshacer/|/was not merged into/"
ctl p8-idioma-store --only=p8 --rewrite=html-lang-store "--expect=/^P8 \\[staging\\] home: the served HTML declares lang=/|/^P8 \\[staging\\] product: the served HTML declares lang=/"
ctl p4-sin-datos-estructurados --only=p4 --rewrite=drop-structured-data "--expect=/reloj-coach-talia-saddle: one valid JSON-LD block is rendered/|/bolso-steve-madden-crossbody-3: one valid JSON-LD block is rendered/"
ctl p3-radios-sin-js --only=p3 --rewrite=show-radios-no-js "--expect=/no radio chip is shown/|/choosing another available variant makes the form send exactly that variant/|/a native form submission adds exactly the chosen variant/"

# Reproducciones de la auditoría, repetidas sobre el código corregido (las «antes» están en ../antes)
step reproducciones-despues node "$OUT/reproducir-auditoria.mjs" --out=despues
# Theme Check frente a la base, hallazgo por hallazgo
step theme-check node "$S/theme-check-compare.mjs" --out="$OUT/despues/theme-check"
# Descarga del borrador y comparación con el local
step compare-remote node "$S/compare-remote.mjs" --out="$OUT/despues"

END_TREE="$(tree)"
echo "# $(date -u +%FT%TZ) fin · árbol $END_TREE · $( [ "$START_TREE" = "$END_TREE" ] && echo 'sin cambios durante la ejecución' || echo 'EL ÁRBOL CAMBIÓ DURANTE LA EJECUCIÓN: los resultados no valen para un único estado de código')" | tee -a "$LOG"
node "$S/runs-index.mjs" | tee -a "$LOG"
