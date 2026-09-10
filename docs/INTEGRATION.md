# Integration contract

- Wazuh manager API: `https://10.40.0.4:15500`
- Wazuh indexer API: `https://10.40.0.4:19200`
- Dashboard: `https://10.40.0.4:15601`
- Agent traffic: TCP 1514/1515 and UDP 514 on private address 10.40.0.4.
- Middleware must use a least-privilege Wazuh API service account.
- Alert forwarding must preserve `rule.id`, `rule.level`, `agent.id`, `service`, and `request_id`.
- Credentials and certificate private keys must remain on the host or in OpenBao, never in Git.
