#!/bin/zsh
cd /Users/alexis_reyna/MyCode/Monetta/design-prototype
EV=../docs/web-redesign/correcciones-reaudit-gpt-2026-10-18
stamp() { echo "## $1 · $(date '+%Y-%m-%d %H:%M:%S %Z') · A = copia anterior (E0) · B = dist de E1 $(node $EV/estado-del-arbol.mjs --root=. | sed 's/.*tree //')"; }
{ stamp "inicio comparación de píxeles"; node $EV/comparar-pixeles.mjs --out=$EV/comparacion-pixeles --a=http://127.0.0.1:4601 --b=http://127.0.0.1:4602 --viewports=375x812,440x956,768x1024,1024x768,1440x900,1060x768; echo "## exit $?"; stamp "fin"; } > $EV/logs/comparacion-pixeles.log 2>&1
echo done > $EV/logs/_pixeles.fin
