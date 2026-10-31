#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin"
export TEST_LOG="$tmp_dir/log"

# Every tool the capture runs only records that it ran; slurp returns no
# selection, as a cancelled pick does.
for stub in hyprpicker slurp grim tesseract wl-copy omarchy-notification-send sleep; do
  cat >"$tmp_dir/bin/$stub" <<'SH'
#!/bin/bash
printf '%s\n' "$(basename "$0")" >>"$TEST_LOG"
SH
  chmod +x "$tmp_dir/bin/$stub"
done

# pgrep finds slurp only while a pick is open.
cat >"$tmp_dir/bin/pgrep" <<SH
#!/bin/bash
[[ -f $tmp_dir/picking ]]
SH
chmod +x "$tmp_dir/bin/pgrep"

capture_text() {
  : >"$TEST_LOG"
  PATH="$tmp_dir/bin:$ROOT/bin:$PATH" "$ROOT/bin/omarchy-capture-text"
}

capture_text
grep -qx hyprpicker "$TEST_LOG" && grep -qx slurp "$TEST_LOG" ||
  fail "OCR capture freezes the screen and picks a region" "$(cat "$TEST_LOG")"
pass "OCR capture freezes the screen and picks a region"

# Pressing the shortcut again while a pick is open must not stack another
# freeze over the first, which whitens the screen a step each time.
touch "$tmp_dir/picking"
capture_text
! grep -qx hyprpicker "$TEST_LOG" && ! grep -qx slurp "$TEST_LOG" ||
  fail "a second OCR capture leaves the open pick alone" "$(cat "$TEST_LOG")"
pass "a second OCR capture leaves the open pick alone"
