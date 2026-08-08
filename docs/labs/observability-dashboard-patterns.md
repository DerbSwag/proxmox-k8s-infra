# Observability Dashboard Patterns

The original Grafana exports use environment-specific datasource and dashboard UIDs, so they are not published as raw JSON. Recreate the following portable panels with your own datasource bindings:

- Kubernetes namespace CPU and memory usage.
- Pod readiness and restart rate.
- Backup job result and age of newest successful archive.
- Persistent-volume capacity and growth trend.
- Log volume and error-rate panels backed by Loki.

Keep datasource UIDs, dashboard UIDs, internal links, and label values environment-local. Export a dashboard only after reviewing those fields and replacing them with portable placeholders.
