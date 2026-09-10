#!/usr/bin/env bash
set -Eeuo pipefail
readonly PUBLIC_DOCKER_CONFIG=/var/lib/codestra/docker-public
install -d -m 0700 "$PUBLIC_DOCKER_CONFIG"
if [[ ! -f "$PUBLIC_DOCKER_CONFIG/config.json" ]]; then
  printf '%s\n' '{"auths":{}}' > "$PUBLIC_DOCKER_CONFIG/config.json"
  chmod 0600 "$PUBLIC_DOCKER_CONFIG/config.json"
fi
export DOCKER_CONFIG="$PUBLIC_DOCKER_CONFIG"
readonly ROOT=/opt/codestra-wazuh
readonly UPSTREAM="$ROOT/upstream"
readonly RELEASE=v4.14.7
install -d -m 0750 "$ROOT"
cat >/etc/sysctl.d/90-wazuh-indexer.conf <<'EOF'
vm.max_map_count=262144
EOF
sysctl --system >/dev/null
if [[ ! -d "$UPSTREAM/.git" ]]; then
  git clone --depth 1 --branch "$RELEASE" https://github.com/wazuh/wazuh-docker.git "$UPSTREAM"
else
  git -C "$UPSTREAM" fetch --depth 1 origin "refs/tags/$RELEASE:refs/tags/$RELEASE"
  git -C "$UPSTREAM" checkout --detach "$RELEASE"
fi
cd "$UPSTREAM/single-node"
python3 - <<'PY'
from pathlib import Path
p=Path("docker-compose.yml")
s=p.read_text()
pairs={
'"1514:1514"':'"10.40.0.4:1514:1514"',
'"1515:1515"':'"10.40.0.4:1515:1515"',
'"514:514/udp"':'"10.40.0.4:514:514/udp"',
'"55000:55000"':'"10.40.0.4:15500:55000"',
'"9200:9200"':'"10.40.0.4:19200:9200"',
'- 443:5601':'- "10.40.0.4:15601:5601"',
}
for old,new in pairs.items():
    if old not in s and new not in s:
        raise SystemExit(f"missing expected mapping: {old}")
    s=s.replace(old,new)
p.write_text(s)
PY
if [[ ! -f config/wazuh_indexer_ssl_certs/root-ca.pem ]]; then
  docker compose -f generate-indexer-certs.yml run --rm generator
fi
docker compose config -q
docker compose up -d
for _ in $(seq 1 60); do
  curl -kfsS https://10.40.0.4:15601/ >/dev/null && exit 0
  sleep 10
done
docker compose ps
exit 1
