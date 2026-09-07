#!/bin/sh
# Copies ThirdParty/node into the app bundle Resources for EV2 conversion.
set -eu

NODE_SRC="${SRCROOT}/ThirdParty/node"
NODE_BIN="${NODE_SRC}/bin/node"
NODE_DST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/node"
FETCH_SCRIPT="${SRCROOT}/../tool/fetch_bundled_node.sh"

if [ ! -x "${NODE_BIN}" ] && [ -x "${FETCH_SCRIPT}" ]; then
  echo "Bundled Node.js missing; fetching via ${FETCH_SCRIPT}"
  /bin/bash "${FETCH_SCRIPT}"
fi

if [ ! -x "${NODE_BIN}" ]; then
  echo "warning: Bundled Node.js not found at ${NODE_BIN}. EV2 conversion will fall back to system Node."
  exit 0
fi

rm -rf "${NODE_DST}"
mkdir -p "$(dirname "${NODE_DST}")"
ditto "${NODE_SRC}" "${NODE_DST}"
chmod +x "${NODE_DST}/bin/node"
echo "Bundled Node.js into ${NODE_DST}"
