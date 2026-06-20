# Incident: Vault dev-mode lost all config on restart (fastapi-vault 403)

**Date:** 2026-06-04
**Severity:** Medium
**Status:** RESOLVED
**Impact:** `fastapi-vault` pod stuck in Init (vault-agent could not authenticate). Any Vault-dependent workload would fail after a Vault pod restart.

## Symptoms

- `fastapi-vault` pod: `Init:0/1` for 17h
- vault-agent-init logs: first `connection refused`, later `403 permission denied`
- Vault Kubernetes auth role `fastapi` and secret `secret/fastapi/db` missing

## Root Cause

Vault was deployed via Helm with `server.dev.enabled: true` (dev mode):
- Storage type `inmem` (in-memory) — all data lost on every pod restart
- During the rolling reboot on 2026-06-03, the Vault pod restarted and wiped the k8s auth method, the `fastapi` role, and all secrets

## Resolution (permanent)

1. Switched Vault to **standalone mode with file storage on a PVC** (`helm/vault/values.yaml`):
   - `server.standalone.enabled: true`, `storage "file"` at `/vault/data`
   - `server.dataStorage` → 1Gi PVC (local-path)
2. Recreated StatefulSet (delete `--cascade=orphan` + `helm upgrade`) and PVC
3. Bootstrapped via `scripts/bootstrap-vault.sh`:
   - init (1 key share) → save keys to `~/vault-init-keys.json` (chmod 600)
   - unseal
   - enable kubernetes auth + kv v2
   - write `auth/kubernetes/config` with `token_reviewer_jwt`, `kubernetes_ca_cert`, `disable_iss_validation=true`
   - create `fastapi` policy + role (bound to `fastapi-sa`/`default`) + seed `secret/fastapi/db`
4. Restarted `fastapi-vault` → **2/2 Running** ✅

## Gotchas hit during fix

- First `auth/kubernetes/config` without CA cert + token reviewer JWT → 403. k3s requires both explicitly.
- A re-run of an early bootstrap truncated the keys file (`init > $KEYS_FILE` ran again). Script now guards against overwriting a non-empty keys file.

## Follow-ups

- **Standalone Vault does NOT auto-unseal.** After any restart it starts sealed → must run unseal (key in `~/vault-init-keys.json`). Consider auto-unseal (transit/KMS) or storing unseal key in sealed-secrets.
- Rotate the seeded `secret/fastapi/db` password (currently placeholder).
- `vault-init-keys.json` lives only on master `~devops`. Back it up to sealed-secrets.

## Lessons Learned

- Never run Vault in dev mode for anything that must survive a restart.
- All bootstrap config is now code in `scripts/bootstrap-vault.sh` — reproducible.
