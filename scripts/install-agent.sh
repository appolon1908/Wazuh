#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <manager-private-ip> <agent-name>" >&2
  exit 2
fi

readonly MANAGER="$1"
readonly AGENT_NAME="$2"
readonly AGENT_RELEASE="${WAZUH_AGENT_RELEASE:-4.14.7}"
readonly KEYRING=/usr/share/keyrings/wazuh.gpg
export DEBIAN_FRONTEND=noninteractive

. /etc/os-release
case "$ID" in
  ubuntu|debian) ;;
  *) echo "This installer supports Debian and Ubuntu endpoints." >&2; exit 3 ;;
esac

apt-get update -qq
apt-get install -y -qq gnupg apt-transport-https ca-certificates curl

if [[ ! -s "$KEYRING" ]]; then
  key_file="$(mktemp)"
  trap 'rm -f "$key_file"' EXIT
  curl -fsS https://packages.wazuh.com/key/GPG-KEY-WAZUH -o "$key_file"
  gpg --batch --no-default-keyring --keyring "gnupg-ring:$KEYRING" --import "$key_file"
  chmod 0644 "$KEYRING"
fi

printf '%s\n' 'deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main' \
  > /etc/apt/sources.list.d/wazuh.list
apt-get update -qq

candidate="$(apt-cache policy wazuh-agent | sed -n 's/^[[:space:]]*Candidate:[[:space:]]*//p')"
case "$candidate" in
  "$AGENT_RELEASE"-*) ;;
  *) echo "Expected Wazuh agent $AGENT_RELEASE, found candidate $candidate" >&2; exit 4 ;;
esac

WAZUH_MANAGER="$MANAGER" \
WAZUH_REGISTRATION_SERVER="$MANAGER" \
WAZUH_AGENT_NAME="$AGENT_NAME" \
  apt-get install -y -qq "wazuh-agent=$candidate"

systemctl daemon-reload
systemctl enable wazuh-agent >/dev/null
systemctl restart wazuh-agent
echo 'wazuh-agent hold' | dpkg --set-selections

systemctl is-active --quiet wazuh-agent
printf 'Wazuh agent %s is active and points to %s.\n' "$AGENT_NAME" "$MANAGER"
