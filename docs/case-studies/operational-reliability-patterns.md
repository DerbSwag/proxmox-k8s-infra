# Operational Reliability Patterns

This case-study collection is intentionally sanitized. Names, addresses, credentials, and environment-specific identifiers are omitted; the operating patterns are reusable.

## Backup staging retention

A daily control-plane and persistent-volume backup can still exhaust the source node even when it is copied off-node. The common trap is using `find -mtime +N`, which preserves more than the intended number of daily sets. Use a clearly defined retention window, validate the newest archive before cleanup, and monitor staging size, backup age, and per-worker results.

## Cross-subnet Zabbix agents

When Zabbix Server runs in Kubernetes, an agent may observe a pod CIDR, node address, or SNAT address as its passive-check source. A TCP connection can therefore succeed while the agent rejects the request. Diagnose from the server pod, verify the observed source address, and allow only the required CIDRs in the agent configuration and firewall.

## Metrics-port regressions

An application can be healthy while its monitoring is blind. In one pattern, DNS requests continued to work but a default-deny NetworkPolicy allowed only the DNS service port and blocked the metrics endpoint. Validate the user-facing service separately from Prometheus `up`; allow both service and metrics ports explicitly; retain the rule in Git so recovery does not reintroduce the false alert.

## Time consistency

For alert timestamps, check the node clock, monitoring server, frontend container, user-profile timezone, and Windows sources separately. An exact whole-hour offset normally indicates a timezone configuration problem; irregular drift points to NTP or host-clock health.
