#!/usr/bin/env bash
# Runs reproduce.sh in Docker's node:26 image (Debian) with bun 1.4.4, on a copy of this folder.
set -euo pipefail
here=$(cd "$(dirname "$0")" && { pwd -W 2> /dev/null || pwd; })
exec docker run --rm -v "$here:/source:ro" node:26 bash -c '
  set -euo pipefail
  npm install --global --silent bun@1.4.4 > /dev/null 2>&1
  cp -r /source /repro
  rm -rf /repro/node_modules
  . /etc/os-release
  echo "$PRETTY_NAME, node $(node --version), bun $(bun --version)"
  exec bash /repro/reproduce.sh
'
