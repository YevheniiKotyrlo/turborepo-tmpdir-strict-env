#!/usr/bin/env bash
# Runs app-a's `tmpdir` script, which prints TMPDIR, os.tmpdir() and REPRO_UNLISTED, a variable no pass-through list
# names, with TMPDIR set to a new folder and REPRO_UNLISTED=1, three ways: through bun alone, through
# `turbo run tmpdir` (strict environment mode, the default), and through `turbo run tmpdir --env-mode=loose`. Prints
# `turbo info` and the line each run's task printed.
# Exits 1 while the strict-mode task runs without TMPDIR and without REPRO_UNLISTED, 0 once it has TMPDIR and still not
# REPRO_UNLISTED, and 2 when a step fails, bun alone or loose mode does not print both, or strict mode prints anything
# else, REPRO_UNLISTED among it.
set -Eeuo pipefail
trap 'echo "failed: $BASH_COMMAND" >&2; exit 2' ERR
cd "$(dirname "$0")"
bun install --frozen-lockfile > install.log 2>&1 || { cat install.log; exit 2; }
folder=$(mktemp -d)
logs=$(mktemp -d)
trap 'rm -rf "$folder" "$logs"' EXIT
echo '$ turbo info'
bunx turbo info 2>&1
export TMPDIR=$folder REPRO_UNLISTED=1
# Runs the command after the name, keeping its output in a log of that name; prints the log and exits 2 when it fails.
run_task() {
  local name=$1 status=0
  shift
  "$@" > "$logs/$name.log" 2>&1 || status=$?
  if [ "$status" != 0 ]; then
    cat "$logs/$name.log"
    echo "$name: $* exited $status"
    exit 2
  fi
}
run_task alone bun run --cwd=apps/app-a tmpdir
run_task strict bunx turbo run tmpdir --filter=app-a --log-prefix=none
run_task loose bunx turbo run tmpdir --filter=app-a --log-prefix=none --env-mode=loose
alone=$(grep '^TMPDIR=' "$logs/alone.log" || true)
strict=$(grep '^TMPDIR=' "$logs/strict.log" || true)
loose=$(grep '^TMPDIR=' "$logs/loose.log" || true)
echo
echo "TMPDIR set to $folder, REPRO_UNLISTED set to 1"
echo "bun run tmpdir: ${alone:-no TMPDIR line}"
echo "turbo run tmpdir: ${strict:-no TMPDIR line}"
echo "turbo run tmpdir --env-mode=loose: ${loose:-no TMPDIR line}"
everything="TMPDIR=$folder, os.tmpdir()=$folder, REPRO_UNLISTED=1"
if [ "$alone" != "$everything" ] || [ "$loose" != "$everything" ]; then
  echo 'bun alone or loose mode did not print the folder TMPDIR names and REPRO_UNLISTED'
  exit 2
fi
case $strict in
  "TMPDIR=$folder, os.tmpdir()=$folder, REPRO_UNLISTED=<unset>")
    echo 'strict mode keeps TMPDIR and still leaves out REPRO_UNLISTED'
    exit 0
    ;;
  'TMPDIR=<unset>, os.tmpdir()='*', REPRO_UNLISTED=<unset>')
    echo 'strict mode drops TMPDIR'
    exit 1
    ;;
esac
echo 'strict mode printed neither the folder alone nor TMPDIR unset'
exit 2
