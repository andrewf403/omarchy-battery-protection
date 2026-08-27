#!/usr/bin/bash

set -euo pipefail

readonly PLUGIN_ID="andrewf.battery-protection"
readonly MENU_BEGIN="// begin $PLUGIN_ID menu entry"
readonly MENU_END="// end $PLUGIN_ID menu entry"
readonly EXTENSIONS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/extensions"
readonly MENU_FILE="$EXTENSIONS_DIR/omarchy-menu.jsonc"

TEMP_CLEANED=""
TEMP_STAGED=""

cleanup() {
  [[ -z $TEMP_CLEANED ]] || rm -f -- "$TEMP_CLEANED"
  [[ -z $TEMP_STAGED ]] || rm -f -- "$TEMP_STAGED"
}
trap cleanup EXIT

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
  install -d -m 0755 "$EXTENSIONS_DIR"
  if [[ ! -e $MENU_FILE ]]; then
    printf '{\n}\n' > "$MENU_FILE"
  fi
  [[ -f $MENU_FILE && ! -L $MENU_FILE ]] || {
    echo "Refusing to modify non-regular menu file: $MENU_FILE" >&2
    exit 1
  }

  TEMP_CLEANED=$(mktemp "$EXTENSIONS_DIR/.omarchy-menu.clean.XXXXXX")
  TEMP_STAGED=$(mktemp "$EXTENSIONS_DIR/.omarchy-menu.new.XXXXXX")
  rewrite_without_entry "$MENU_FILE" "$TEMP_CLEANED"

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

  chmod --reference="$MENU_FILE" "$TEMP_STAGED"
  mv -f -- "$TEMP_STAGED" "$MENU_FILE"
  TEMP_STAGED=""
  echo "Added Battery Protection to Trigger > Hardware."
}

remove_entry() {
  [[ -e $MENU_FILE ]] || return 0
  [[ -f $MENU_FILE && ! -L $MENU_FILE ]] || {
    echo "Refusing to modify non-regular menu file: $MENU_FILE" >&2
    exit 1
  }
  grep -Fq "$MENU_BEGIN" "$MENU_FILE" || return 0

  TEMP_STAGED=$(mktemp "$EXTENSIONS_DIR/.omarchy-menu.new.XXXXXX")
  rewrite_without_entry "$MENU_FILE" "$TEMP_STAGED"
  chmod --reference="$MENU_FILE" "$TEMP_STAGED"
  mv -f -- "$TEMP_STAGED" "$MENU_FILE"
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
