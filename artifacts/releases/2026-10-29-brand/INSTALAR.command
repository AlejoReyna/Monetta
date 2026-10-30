#!/bin/zsh
set -euo pipefail
HERE=${0:A:h}
DEVICE_ID=00008140-000954AA3ED0801C
xcrun devicectl device install app --device "$DEVICE_ID" "$HERE/package/Payload/Runner.app"
xcrun devicectl device process launch --device "$DEVICE_ID" mx.monetta.monettaApp.staging
