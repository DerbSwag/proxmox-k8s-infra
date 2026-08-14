# Linux Lab Foundations

Public-safe, reusable examples distilled from a small Ubuntu lab VM. They show the building blocks used before moving workloads into Kubernetes: a containerized application, a stateful Compose dependency, and simple host health checks.

## Contents

| Path | Purpose |
| --- | --- |
| `python-http/` | Minimal Python HTTP container with health and readiness endpoints. |
| `postgres-compose/` | PostgreSQL Compose stack that waits for database health before starting a client container. |
| `scripts/` | Small shell checks for disk capacity and systemd service state. |

## Run the Python example

```bash
cd python-http
docker build -t example-python-http:local .
docker run --rm -p 5000:5000 example-python-http:local
curl http://localhost:5000/healthz
```

## Run the PostgreSQL example

```bash
cd postgres-compose
cp .env.example .env
# Set POSTGRES_PASSWORD to a unique local-only value.
docker compose up --build
```

The named volume retains database data. Remove it only when a reset is intended:

```bash
docker compose down --volumes
```

## Public-safety notes

- `.env`, database dumps, certificates, private keys, SSH material, and container volumes are deliberately excluded.
- Do not commit a real `.env`; `.env.example` contains placeholders only.
- Review exposed ports and credentials before using these examples beyond an isolated lab.
