#!/usr/bin/env bash
set -euo pipefail

# Sonarpad keeps flutter_tts 4.2.5 unchanged and applies only upstream PR #632,
# which fixes the iOS synthesizeToFile crash when AVSpeechSynthesizer emits
# Int16 PCM buffers. Normal TTS playback/VoiceOver reading is not modified.
readonly FLUTTER_TTS_VERSION="4.2.5"
readonly PATCH_URL="https://github.com/dlutton/flutter_tts/pull/632.patch"

find_plugin_dir() {
  local root
  local found
  for root in \
    "${PUB_CACHE:-}" \
    "$HOME/.pub-cache" \
    "$HOME/Library/Caches/dart-pub"; do
    [[ -n "$root" && -d "$root" ]] || continue
    found="$(find "$root" -type d -name "flutter_tts-${FLUTTER_TTS_VERSION}" -prune -print 2>/dev/null | head -n 1 || true)"
    if [[ -n "$found" ]]; then
      printf '%s\n' "$found"
      return 0
    fi
  done

  echo "flutter_tts ${FLUTTER_TTS_VERSION} non trovato nella Pub cache." >&2
  return 1
}

plugin_dir="$(find_plugin_dir)"
marker_file="$plugin_dir/.sonarpad_flutter_tts_pr632_applied"

if [[ -f "$marker_file" ]]; then
  echo "Patch flutter_tts #632 gia applicata a $plugin_dir"
  exit 0
fi

patch_file="$(mktemp "${TMPDIR:-/tmp}/sonarpad-flutter-tts-632.XXXXXX")"
trap 'rm -f "$patch_file"' EXIT

curl --fail --silent --show-error --location "$PATCH_URL" --output "$patch_file"

# Safety guard: this Sonarpad hotfix must remain iOS-only and must never change
# Dart APIs, Android code, speaking/reading logic, or any other plugin files.
changed_files="$(sed -nE 's#^diff --git a/([^ ]+) b/.*#\1#p' "$patch_file" | sort -u)"

if [[ -z "$changed_files" ]]; then
  echo "Patch flutter_tts #632 vuota o non riconosciuta." >&2
  exit 1
fi

while IFS= read -r changed; do
  [[ -n "$changed" ]] || continue
  case "$changed" in
    ios/Classes/*)
      ;;
    *)
      echo "Rifiuto patch flutter_tts #632: modifica inattesa fuori da ios/Classes: $changed" >&2
      exit 1
      ;;
  esac
done <<< "$changed_files"

# Fresh GitHub runners normally take this branch. -N prevents an accidental
# second application if a restored Pub cache already contains the hotfix.
if patch -N -s -d "$plugin_dir" -p1 < "$patch_file"; then
  printf '%s\n' "$(shasum -a 256 "$patch_file" | awk '{print $1}')" > "$marker_file"
  echo "Applicata patch flutter_tts #632 a $plugin_dir"
else
  echo "Impossibile applicare in modo pulito la patch flutter_tts #632 a flutter_tts ${FLUTTER_TTS_VERSION}." >&2
  echo "Interrompo invece di modificare codice TTS non previsto." >&2
  exit 1
fi
