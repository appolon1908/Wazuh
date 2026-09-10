#!/usr/bin/env bash
set -Eeuo pipefail
cd /opt/codestra-wazuh/upstream/single-node
docker compose ps
curl -kfsS https://10.40.0.4:15601/ >/dev/null
curl -kfsS https://10.40.0.4:15500/ >/dev/null
