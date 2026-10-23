#!/bin/bash
# Optional: lets Anchorlight toggle the setting without an admin password prompt.
#
#   sudo ./scripts/install-sudoers.sh            # install
#   sudo ./scripts/install-sudoers.sh --remove   # undo
#
# It grants NOPASSWD for exactly two commands and nothing else:
#   /usr/bin/pmset -a disablesleep 0
#   /usr/bin/pmset -a disablesleep 1
set -euo pipefail

DEST="/etc/sudoers.d/anchorlight-pmset"
USER_NAME="${SUDO_USER:-$(id -un)}"

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run this with sudo: sudo $0 $*" >&2
	exit 1
fi

if [[ "${1:-}" == "--remove" ]]; then
	rm -f "$DEST"
	# Earlier builds installed the same rule under the app's previous name.
	rm -f /etc/sudoers.d/sleepguard-pmset
	echo "Removed $DEST"
	exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
cat > "$TMP" <<RULE
# Installed by Anchorlight (scripts/install-sudoers.sh)
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
RULE

visudo -cqf "$TMP"
install -m 0440 -o root -g wheel "$TMP" "$DEST"
echo "Installed $DEST for user '$USER_NAME'"
