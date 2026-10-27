#!/bin/zsh
# Validation sequence of the guide 1:1 pass, run against the authenticated `shopify theme dev` proxy of the draft theme.
# The checks of the 22 Oct pass plus this pass's own (guia-checks.mjs, once it exists), one command at a time (the proxy is
# the bottleneck), each with its exit code in <out>/validate.log. Browser results land in guia-1a1/evidencia/runs/ (kept out
# of git) through scripts/e2e/lib.mjs ($MONETTA_RUNS_DIR).
#   docs/web-redesign/shopify-staging/guia-1a1/scripts/validate.sh <label> [base-url]
set -u
ROOT=${0:A:h:h:h:h:h:h}
LABEL=${1:?label, e.g. f0-antes}
B=${2:-http://127.0.0.1:9292}
S=$ROOT/docs/web-redesign/shopify-staging
E=$S/scripts/e2e
D=$S/design-language-2026-10-22
G=$S/guia-1a1
OUT=$G/evidencia/validation/$LABEL
export MONETTA_RUNS_DIR=$G/evidencia/runs
mkdir -p $OUT $MONETTA_RUNS_DIR
LOG=$OUT/validate.log
cd $ROOT || exit 1

step() {
  local name=$1; shift
  local started=$(date -u +%FT%TZ)
  "$@" > "$OUT/$name.out" 2>&1
  local code=$?
  echo "$started  exit=$code  $name  ::  $*" >> $LOG
}

echo "# validate.sh $LABEL $(date -u +%FT%TZ) base=$B head=$(git rev-parse --short HEAD) dirty=$(git status --porcelain -- storefront-theme | wc -l | tr -d ' ')" >> $LOG
step build-check node design-system/build.mjs --check
step port-parity node tools/style-guideline-theme/port-css.mjs --check
step theme-check-diff node $D/scripts/theme-check-diff.mjs --out=$OUT/theme-check
[ -f $G/scripts/guia-checks.mjs ] && step guia-checks node $G/scripts/guia-checks.mjs --base-url=$B --phases=${GUIA_PHASES:-f1,f2} --name=$LABEL-guia-checks
step dl-checks node $D/scripts/checks.mjs --base-url=$B --flows --name=$LABEL-dl-checks
for vp in 390x844 768x1024 1024x768 1440x900; do
  step journey-$vp node $E/journey.mjs --base-url=$B --w=${vp%x*} --h=${vp#*x}
done
step axe node $E/axe.mjs --base-url=$B
step motion node $E/motion.mjs --base-url=$B
step nav node $E/nav.mjs --base-url=$B
step keyboard node $E/keyboard.mjs --base-url=$B
step layout node $E/layout.mjs --base-url=$B
step regressions node $E/regressions.mjs --base-url=$B
echo "# done $(date -u +%FT%TZ)" >> $LOG
