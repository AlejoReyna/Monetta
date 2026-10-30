#!/bin/zsh
# Validation sequence of the design-language pass, run against the authenticated `shopify theme dev` proxy of the draft theme.
# One command at a time (the proxy is the bottleneck), each with its exit code in validation/validate.log. Browser results land
# in docs/web-redesign/shopify-staging/runs/<stamp>-<name>/ through scripts/e2e/lib.mjs.
#   docs/web-redesign/shopify-staging/design-language-2026-10-22/scripts/validate.sh [base-url]
set -u
ROOT=/Users/alexis_reyna/MyCode/Monetta
B=${1:-http://127.0.0.1:9292}
E=$ROOT/docs/web-redesign/shopify-staging/scripts/e2e
D=$ROOT/docs/web-redesign/shopify-staging/design-language-2026-10-22
OUT=$D/validation
mkdir -p $OUT
LOG=$OUT/validate.log
cd $ROOT || exit 1

step() {
  local name=$1; shift
  local started=$(date -u +%FT%TZ)
  "$@" > "$OUT/$name.out" 2>&1
  local code=$?
  echo "$started  exit=$code  $name  ::  $*" >> $LOG
}

echo "# validate.sh $(date -u +%FT%TZ) base=$B head=$(git rev-parse --short HEAD)" >> $LOG
step build-check node design-system/build.mjs --check
step port-parity node docs/web-redesign/shopify-staging/scripts/port-css.mjs --check
step theme-check-diff node $D/scripts/theme-check-diff.mjs --out=$OUT/theme-check
step dl-checks node $D/scripts/checks.mjs --base-url=$B --flows --name=dl-checks
# Negative controls: each reintroduces one defect this pass fixed; the matching checks must fail.
step nc-blanket-serif node $D/scripts/checks.mjs --base-url=$B --viewports=390x844 --name=negative-control-dl-blanket-serif --inject-css='.mw :is(h1,h2,h3,h4,h5,h6){font-family:var(--font-serif) !important}'
step nc-single-gallery node $D/scripts/checks.mjs --base-url=$B --viewports=1440x900 --name=negative-control-dl-single-gallery --inject-css='@media (min-width:1024px){.gallery--single{display:grid !important}}'
step nc-discount-overflow node $D/scripts/checks.mjs --base-url=$B --viewports=320x640 --name=negative-control-dl-discount-overflow --inject-css='.discount-form input{width:auto !important}.discount-form__row{display:flex !important}'
step nc-fav-target node $D/scripts/checks.mjs --base-url=$B --viewports=390x844 --name=negative-control-dl-fav-40 --inject-css='.mw .card__fav{width:40px !important;height:40px !important}'
for vp in 390x844 768x1024 1024x768 1440x900; do
  step journey-$vp node $E/journey.mjs --base-url=$B --w=${vp%x*} --h=${vp#*x}
done
step axe node $E/axe.mjs --base-url=$B
step motion node $E/motion.mjs --base-url=$B
step nav node $E/nav.mjs --base-url=$B
step keyboard node $E/keyboard.mjs --base-url=$B
step layout node $E/layout.mjs --base-url=$B
step regressions node $E/regressions.mjs --base-url=$B
step runs-index node $ROOT/docs/web-redesign/shopify-staging/scripts/runs-index.mjs
echo "# done $(date -u +%FT%TZ)" >> $LOG
