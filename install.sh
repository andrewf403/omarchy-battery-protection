#!/usr/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
"$script_dir/menu.sh" install
omarchy bar move andrewf.battery-protection --before omarchy.power
