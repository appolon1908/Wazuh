#!/usr/bin/env bash
set -Eeuo pipefail

cd /opt/codestra-wazuh/upstream/single-node
docker compose ps

check_http() {
  local name="$1"
  local url="$2"
  local allowed="$3"
  local code

  code="$(curl -ksS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 15 "$url")"
  case " $allowed " in
    *" $code "*) printf '%s HTTP %s\n' "$name" "$code" ;;
    *) printf '%s unhealthy: HTTP %s (expected %s)\n' "$name" "$code" "$allowed" >&2; return 1 ;;
  esac
}

check_http "dashboard" "https://10.40.0.4:15601/" "200 302"
check_http "manager-api" "https://10.40.0.4:15500/" "200 401"
check_http "indexer" "https://10.40.0.4:19200/" "200 401"
