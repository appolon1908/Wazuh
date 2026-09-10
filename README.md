# Codestra Wazuh

Governed Wazuh 4.14.7 single-node deployment for security monitoring.

- Target: 37.27.128.39 / private 10.40.0.4
- Public dashboard: https://wazuh.codestra.co
- Private dashboard: https://10.40.0.4:15601
- Private API: https://10.40.0.4:15500
- Private indexer: https://10.40.0.4:19200
- Agent enrollment, events, API, and indexer traffic remain private-vSwitch only.
- Rotated credentials are stored only on the manager at `/etc/codestra/secrets/wazuh.env` with mode 0600.

## Active integrations

| Agent | Private IP | Purpose |
|---|---:|---|
| `production-middleware` | `10.40.0.1` | Production middleware |
| `platform-edge-49-12-145-107` | `10.40.0.3` | Platform edge host |
| `observability-37-27-128-39` | `10.40.0.4` | Observability host |

Run `sudo ./scripts/deploy.sh` on the manager. To enroll another Ubuntu or Debian server, run:

```bash
sudo ./scripts/install-agent.sh 10.40.0.4 unique-agent-name
```

Use `sudo ./scripts/status.sh` for manager service health.
