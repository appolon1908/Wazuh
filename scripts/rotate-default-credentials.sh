#!/usr/bin/env bash
set -Eeuo pipefail
readonly ROOT=/opt/codestra-wazuh
readonly STACK="$ROOT/upstream/single-node"
readonly SECRET_DIR=/etc/codestra/secrets
readonly SECRET_FILE="$SECRET_DIR/wazuh.env"
readonly PUBLIC_DOCKER_CONFIG=/var/lib/codestra/docker-public
export DOCKER_CONFIG="$PUBLIC_DOCKER_CONFIG"
install -d -m 0700 "$SECRET_DIR"
if [[ -f "$SECRET_FILE" ]]; then
  echo "Wazuh credential file already exists; refusing to rotate implicitly." >&2
  exit 2
fi
umask 077
admin_password="Wa1!$(openssl rand -hex 20)"
api_password="Wu1!$(openssl rand -hex 20)"
admin_hash="$(docker run --rm -e WAZUH_HASH_INPUT="$admin_password" wazuh/wazuh-indexer:4.14.7 bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -env WAZUH_HASH_INPUT | tail -n 1)"
[[ "$admin_hash" == '$2y$'* ]] || { echo "Password hash generation failed" >&2; exit 1; }
cd "$STACK"
docker compose down
ADMIN_PASSWORD="$admin_password" API_PASSWORD="$api_password" ADMIN_HASH="$admin_hash" python3 - <<'PY'
import os,re
from pathlib import Path
compose=Path("docker-compose.yml")
s=compose.read_text()
s=s.replace("SecretPassword", os.environ["ADMIN_PASSWORD"])
s=s.replace("MyS3cr37P450r.*-", os.environ["API_PASSWORD"])
compose.write_text(s)
wazuh=Path("config/wazuh_dashboard/wazuh.yml")
s=wazuh.read_text().replace("MyS3cr37P450r.*-", os.environ["API_PASSWORD"])
wazuh.write_text(s)
users=Path("config/wazuh_indexer/internal_users.yml")
s=users.read_text()
pat=r'(admin:\n(?:.*\n)*?\s+hash:\s*)["\x27][^"\x27]+["\x27]'
s,n=re.subn(pat, lambda m:m.group(1)+'"'+os.environ["ADMIN_HASH"]+'"', s, count=1)
if n != 1:
    raise SystemExit("admin hash block not found")
users.write_text(s)
PY
printf 'WAZUH_ADMIN_USER=admin\nWAZUH_ADMIN_PASSWORD=%s\nWAZUH_API_USER=wazuh-wui\nWAZUH_API_PASSWORD=%s\n' "$admin_password" "$api_password" > "$SECRET_FILE"
chmod 0600 "$SECRET_FILE"
unset admin_password api_password admin_hash
docker compose up -d
for _ in $(seq 1 60); do
  if docker exec single-node-wazuh.indexer-1 bash -c '
    export INSTALLATION_DIR=/usr/share/wazuh-indexer
    export CONFIG_DIR=$INSTALLATION_DIR/config
    export JAVA_HOME=/usr/share/wazuh-indexer/jdk
    bash $INSTALLATION_DIR/plugins/opensearch-security/tools/securityadmin.sh       -cd $CONFIG_DIR/opensearch-security/ -nhnv       -cacert $CONFIG_DIR/certs/root-ca.pem       -cert $CONFIG_DIR/certs/admin.pem       -key $CONFIG_DIR/certs/admin-key.pem -p 9200 -icl
  '; then
    break
  fi
  sleep 5
done
docker compose up -d --force-recreate wazuh.manager wazuh.dashboard
set -a
. "$SECRET_FILE"
set +a
for _ in $(seq 1 36); do
  index_code="$(curl -ksS -u "$WAZUH_ADMIN_USER:$WAZUH_ADMIN_PASSWORD" -o /dev/null -w '%{http_code}' https://10.40.0.4:19200/ || true)"
  api_code="$(curl -ksS -u "$WAZUH_API_USER:$WAZUH_API_PASSWORD" -o /dev/null -w '%{http_code}' https://10.40.0.4:15500/security/user/authenticate || true)"
  if [[ "$index_code" == 200 && "$api_code" == 200 ]]; then
    echo WAZUH_CREDENTIAL_ROTATION=PASS
    exit 0
  fi
  sleep 5
done
echo WAZUH_CREDENTIAL_ROTATION=FAIL >&2
exit 1
