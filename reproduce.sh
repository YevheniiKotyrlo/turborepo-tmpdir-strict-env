#!/usr/bin/env bash
# Runs app-a's `tmpdir` script, which prints TMPDIR and os.tmpdir(), with TMPDIR set to a new folder three ways: through
# bun alone, through `turbo run tmpdir` (strict environment mode, the default), and through `turbo run tmpdir
# --env-mode=loose`. Prints `turbo info` and what each run printed.
# Exits 1 while the strict-mode task loses TMPDIR that the other two runs keep, 0 once all three print the folder, and 2
# when a step fails or bun alone or loose mode does not print the folder.
set -Eeuo pipefail
trap 'echo "failed: $BASH_COMMAND" >&2; exit 2' ERR
cd "$(dirname "$0")"
bun install > install.log 2>&1 || { cat install.log; exit 2; }
folder=$(mktemp -d)
trap 'rm -rf "$folder"' EXIT
echo '$ turbo info'
info=$(bunx turbo info 2>&1)
printf '%s\n' "$info"
tmpdir_line() { grep '^TMPDIR=' || true; }
expected="TMPDIR=$folder, os.tmpdir()=$folder"
alone=$(cd apps/app-a && TMPDIR=$folder bun run tmpdir 2>&1 | tmpdir_line)
strict=$(TMPDIR=$folder bunx turbo run tmpdir --filter=app-a --log-prefix=none 2>&1 | tmpdir_line)
loose=$(TMPDIR=$folder bunx turbo run tmpdir --filter=app-a --log-prefix=none --env-mode=loose 2>&1 | tmpdir_line)
echo
echo "TMPDIR set to $folder"
echo "bun run tmpdir: ${alone:-no TMPDIR line}"
echo "turbo run tmpdir: ${strict:-no TMPDIR line}"
echo "turbo run tmpdir --env-mode=loose: ${loose:-no TMPDIR line}"
if [ "$alone" != "$expected" ] || [ "$loose" != "$expected" ]; then
  echo 'bun alone or loose mode did not print the folder TMPDIR names'
  exit 2
fi
if [ "$strict" = "$expected" ]; then
  echo 'strict mode keeps TMPDIR'
  exit 0
fi
echo 'strict mode drops TMPDIR'
exit 1
