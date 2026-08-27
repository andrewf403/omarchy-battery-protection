#!/usr/bin/bash

set -euo pipefail

readonly PLUGIN_ID="andrewf.battery-protection"
readonly MENU_BEGIN="// begin $PLUGIN_ID menu entry"
readonly MENU_END="// end $PLUGIN_ID menu entry"
readonly EXTENSIONS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/extensions"
readonly MENU_FILE="$EXTENSIONS_DIR/omarchy-menu.jsonc"

TEMP_CLEANED=""
TEMP_STAGED=""
MENU_FD=""
MENU_IDENTITY=""
MENU_CREATED=0

cleanup() {
  [[ -z $MENU_FD ]] || exec {MENU_FD}<&-
  [[ -z $TEMP_CLEANED ]] || rm -f -- "$TEMP_CLEANED"
  [[ -z $TEMP_STAGED ]] || rm -f -- "$TEMP_STAGED"
}
trap cleanup EXIT

open_menu_snapshot() {
  [[ -d $EXTENSIONS_DIR && ! -L $EXTENSIONS_DIR ]] || {
    echo "Refusing to use non-regular extensions directory: $EXTENSIONS_DIR" >&2
    exit 1
  }

  if [[ ! -e $MENU_FILE && ! -L $MENU_FILE ]]; then
    set -o noclobber
    if ! { exec {MENU_FD}> "$MENU_FILE"; } 2>/dev/null; then
      set +o noclobber
      echo "Could not safely create menu file: $MENU_FILE" >&2
      exit 1
    fi
    set +o noclobber

    [[ -f /proc/$$/fd/$MENU_FD ]] || {
      echo "Refusing to create non-regular menu file: $MENU_FILE" >&2
      exit 1
    }
    MENU_IDENTITY=$(stat -Lc '%d:%i' "/proc/$$/fd/$MENU_FD")
    MENU_CREATED=1
    printf '{\n}\n' >&$MENU_FD
    return
  fi

  [[ -f $MENU_FILE && ! -L $MENU_FILE ]] || {
    echo "Refusing to modify non-regular menu file: $MENU_FILE" >&2
    exit 1
  }

  exec {MENU_FD}< "$MENU_FILE" || {
    echo "Could not open menu file: $MENU_FILE" >&2
    exit 1
  }
  [[ -f /proc/$$/fd/$MENU_FD ]] || {
    echo "Refusing to modify non-regular menu file: $MENU_FILE" >&2
    exit 1
  }
  MENU_IDENTITY=$(stat -Lc '%d:%i' "/proc/$$/fd/$MENU_FD")
}

verify_menu_unchanged() {
  local current_identity=""

  [[ -f $MENU_FILE && ! -L $MENU_FILE ]] || {
    echo "Menu file changed during update: $MENU_FILE" >&2
    exit 1
  }
  current_identity=$(stat -c '%d:%i' "$MENU_FILE")
  [[ $current_identity == "$MENU_IDENTITY" ]] || {
    echo "Menu file changed during update: $MENU_FILE" >&2
    exit 1
  }
}

rewrite_without_entry() {
  local source="$1"
  local destination="$2"

  awk -v begin="$MENU_BEGIN" -v end="$MENU_END" '
    !skipping && index($0, begin) { skipping = 1; next }
    skipping && index($0, end) { skipping = 0; next }
    !skipping { print }
    END { if (skipping) exit 1 }
  ' "$source" > "$destination"
}

install_entry() {
  open_menu_snapshot

  TEMP_CLEANED=$(mktemp "$EXTENSIONS_DIR/.omarchy-menu.clean.XXXXXX")
  TEMP_STAGED=$(mktemp "$EXTENSIONS_DIR/.omarchy-menu.new.XXXXXX")
  if (( MENU_CREATED )); then
    printf '{\n}\n' > "$TEMP_CLEANED"
  else
    rewrite_without_entry "/proc/$$/fd/$MENU_FD" "$TEMP_CLEANED"
  fi

  if ! awk -v begin="$MENU_BEGIN" -v end="$MENU_END" '
    { print }
    !inserted && /^[[:space:]]*\{/ {
      print "  " begin
      print "  \"trigger.hardware.battery-protection-upower\": {"
      print "    \"icon\": \"󱞜\","
      print "    \"label\": \"Battery Protection\","
      print "    \"description\": \"Toggle the configured battery charge limit\","
      print "    \"when\": \"~/.config/omarchy/plugins/andrewf.battery-protection/battery-protection supported\","
      print "    \"checked\": \"~/.config/omarchy/plugins/andrewf.battery-protection/battery-protection is-enabled\","
      print "    \"action\": \"~/.config/omarchy/plugins/andrewf.battery-protection/battery-protection toggle --notify\""
      print "  },"
      print "  " end
      inserted = 1
    }
    END { if (!inserted) exit 1 }
  ' "$TEMP_CLEANED" > "$TEMP_STAGED"; then
    echo "Could not add Battery Protection to $MENU_FILE" >&2
    exit 1
  fi

  chmod --reference="/proc/$$/fd/$MENU_FD" "$TEMP_STAGED"
  verify_menu_unchanged
  mv -fT -- "$TEMP_STAGED" "$MENU_FILE"
  TEMP_STAGED=""
  MENU_CREATED=0
  echo "Added Battery Protection to Trigger > Hardware."
}

remove_entry() {
  [[ -e $MENU_FILE || -L $MENU_FILE ]] || return 0
  open_menu_snapshot
  grep -Fq "$MENU_BEGIN" "/proc/$$/fd/$MENU_FD" || return 0

  TEMP_STAGED=$(mktemp "$EXTENSIONS_DIR/.omarchy-menu.new.XXXXXX")
  rewrite_without_entry "/proc/$$/fd/$MENU_FD" "$TEMP_STAGED"
  chmod --reference="/proc/$$/fd/$MENU_FD" "$TEMP_STAGED"
  verify_menu_unchanged
  mv -fT -- "$TEMP_STAGED" "$MENU_FILE"
  TEMP_STAGED=""
  echo "Removed Battery Protection from Trigger > Hardware."
}

case "${1:-}" in
  install) install_entry ;;
  remove) remove_entry ;;
  *)
    echo "Usage: $0 {install|remove}" >&2
    exit 64
    ;;
esac
