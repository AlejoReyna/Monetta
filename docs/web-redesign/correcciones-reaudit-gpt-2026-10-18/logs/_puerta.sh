#!/bin/zsh
# The full gate on the frozen code state; every log carries its time and the tree digest it covers.
cd /Users/alexis_reyna/MyCode/Monetta/design-prototype
EV=../docs/web-redesign/correcciones-reaudit-gpt-2026-10-18
stamp() { echo "## $1 · $(date '+%Y-%m-%d %H:%M:%S %Z') · árbol $(node $EV/estado-del-arbol.mjs --root=. | sed 's/.*tree //')"; }
{ stamp "inicio npm test"; npm test; echo "## exit $?"; stamp "fin npm test"; } > $EV/logs/npm-test.log 2>&1
{ stamp "inicio npm run build"; npm run build; echo "## exit $?"; stamp "fin npm run build"; } > $EV/logs/npm-build.log 2>&1
{ stamp "inicio npm run verify"; npm run verify -- --out=$EV/evidence --port=4621; echo "## exit $?"; stamp "fin npm run verify"; } > $EV/logs/npm-verify.log 2>&1
echo done > $EV/logs/_puerta.fin
