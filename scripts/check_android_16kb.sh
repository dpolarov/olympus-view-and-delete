#!/usr/bin/env bash
set -euo pipefail

APK_PATH="${1:-build/app/outputs/flutter-apk/app-release.apk}"

if [[ ! -f "$APK_PATH" ]]; then
  echo "APK not found: $APK_PATH" >&2
  exit 1
fi

ZIPALIGN="$(find "${ANDROID_HOME:?ANDROID_HOME is not set}/build-tools" -type f -name zipalign -print | sort -V | tail -n 1)"
if [[ -z "$ZIPALIGN" ]]; then
  echo "zipalign not found in Android SDK" >&2
  exit 1
fi

echo "Checking APK ZIP alignment with: $ZIPALIGN"
"$ZIPALIGN" -c -P 16 -v 4 "$APK_PATH"

OBJDUMP="$(find "$ANDROID_HOME/ndk" -type f -name llvm-objdump -print | sort -V | tail -n 1)"
if [[ -z "$OBJDUMP" ]]; then
  echo "llvm-objdump not found in Android NDK" >&2
  exit 1
fi

echo "Checking 64-bit ELF LOAD alignment with: $OBJDUMP"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

unzip -q "$APK_PATH" 'lib/arm64-v8a/*.so' 'lib/x86_64/*.so' -d "$TMP_DIR" || true

mapfile -t LIBS < <(
  find "$TMP_DIR/lib/arm64-v8a" "$TMP_DIR/lib/x86_64" \
    -type f -name '*.so' 2>/dev/null | sort
)
if [[ ${#LIBS[@]} -eq 0 ]]; then
  echo "No arm64-v8a or x86_64 shared libraries found in APK."
  exit 0
fi

FAILED=0
for LIB in "${LIBS[@]}"; do
  LIB_FAILED=0
  while IFS= read -r LINE; do
    EXPONENT="$(sed -n 's/.*align 2\*\*\([0-9][0-9]*\).*/\1/p' <<<"$LINE")"
    if [[ -n "$EXPONENT" ]] && (( EXPONENT < 14 )); then
      LIB_FAILED=1
      break
    fi
  done < <("$OBJDUMP" -p "$LIB" | grep 'LOAD' || true)

  if [[ $LIB_FAILED -ne 0 ]]; then
    echo "ERROR: ${LIB#"$TMP_DIR/"} contains a LOAD segment aligned below 16 KB" >&2
    "$OBJDUMP" -p "$LIB" | grep 'LOAD' >&2 || true
    FAILED=1
  else
    echo "OK: ${LIB#"$TMP_DIR/"}"
  fi
done

if [[ $FAILED -ne 0 ]]; then
  echo "One or more 64-bit native libraries are not 16 KB page-size compatible." >&2
  exit 1
fi

echo "Android 16 KB page-size checks passed for arm64-v8a and x86_64."
