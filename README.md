# Codestra Wazuh

Governed Wazuh 4.14.7 single-node deployment for security monitoring.

- Target: 37.27.128.39 / private 10.40.0.4
- Dashboard: https://10.40.0.4:15601
- API: https://10.40.0.4:15500
- Indexer: https://10.40.0.4:19200
- Agent enrollment and events are private-vSwitch only.

Run `sudo ./scripts/deploy.sh`. Public ingress is intentionally disabled.
