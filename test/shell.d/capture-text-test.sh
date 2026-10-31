#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin" "$tmp_dir/run"
export TEST_LOG="$tmp_dir/log"

# Every tool the capture runs only records that it ran.
for stub in hyprpicker grim tesseract wl-copy omarchy-notification-send sleep; do
  cat >"$tmp_dir/bin/$stub" <<'SH'
#!/bin/bash
printf '%s\n' "$(basename "$0")" >>"$TEST_LOG"
SH
  chmod +x "$tmp_dir/bin/$stub"
done

# slurp waits for the freeze to have started, then returns no selection, as a
# cancelled pick does.
cat >"$tmp_dir/bin/slurp" <<'SH'
#!/bin/bash
for _ in {1..100}; do
  grep -qx hyprpicker "$TEST_LOG" && break
  command -p sleep 0.02
done
printf 'slurp\n' >>"$TEST_LOG"
SH
chmod +x "$tmp_dir/bin/slurp"

capture_text() {
  : >"$TEST_LOG"
  PATH="$tmp_dir/bin:$ROOT/bin:$PATH" XDG_RUNTIME_DIR="$tmp_dir/run" "$ROOT/bin/omarchy-capture-text"
}

capture_text
grep -qx hyprpicker "$TEST_LOG" && grep -qx slurp "$TEST_LOG" ||
  fail "OCR capture freezes the screen and picks a region" "$(cat "$TEST_LOG")"
pass "OCR capture freezes the screen and picks a region"

# Pressing the shortcut again while a capture is under way must not stack
# another freeze over the first, which whitens the screen a step each time.
exec 8>"$tmp_dir/run/omarchy-capture-text.lock"
flock -n 8
capture_text
exec 8>&-
! grep -qx hyprpicker "$TEST_LOG" && ! grep -qx slurp "$TEST_LOG" ||
  fail "a second OCR capture leaves the one under way alone" "$(cat "$TEST_LOG")"
pass "a second OCR capture leaves the one under way alone"

capture_text
grep -qx hyprpicker "$TEST_LOG" ||
  fail "OCR capture runs again once the first has finished" "$(cat "$TEST_LOG")"
pass "OCR capture runs again once the first has finished"
