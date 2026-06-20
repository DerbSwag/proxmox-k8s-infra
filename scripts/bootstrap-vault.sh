#!/usr/bin/env bash
# Bootstrap Vault: init/unseal (if needed), enable k8s auth, create fastapi role + secret.
# Run after deploying standalone Vault. Idempotent where possible.
# Usage: ./scripts/bootstrap-vault.sh
set -euo pipefail
NS=vault
POD=vault-0
KEYS_FILE="${HOME}/vault-init-keys.json"

kx() { kubectl exec -n "$NS" "$POD" -- "$@"; }

# 1. Init (only if not initialized) — saves unseal key + root token locally.
# Guard: never overwrite a non-empty keys file (prevents losing keys on re-run).
if kubectl exec -n "$NS" "$POD" -- vault status -format=json 2>/dev/null | grep -q '"initialized": *false' \
   || ! kubectl exec -n "$NS" "$POD" -- vault status 2>&1 | grep -q "Initialized"; then
  if [ -s "$KEYS_FILE" ]; then
    echo "!! $KEYS_FILE already exists and is non-empty but Vault seems uninitialized. Aborting to avoid key loss." >&2
    exit 1
  fi
  echo ">> Initializing Vault..."
  kx vault operator init -key-shares=1 -key-threshold=1 -format=json > "$KEYS_FILE"
  echo ">> Keys saved to $KEYS_FILE (KEEP SAFE / store in sealed-secrets)"
fi

UNSEAL=$(python3 -c "import json;print(json.load(open('$KEYS_FILE'))['unseal_keys_b64'][0])")
ROOT=$(python3 -c "import json;print(json.load(open('$KEYS_FILE'))['root_token'])")

# 2. Unseal if sealed
if kx vault status 2>/dev/null | grep -q "Sealed.*true"; then
  echo ">> Unsealing..."
  kx vault operator unseal "$UNSEAL"
fi

# 3. Configure auth + secrets (login as root). Uses sh -c with a single string
# (heredoc via `sh -s` does not receive stdin when this script itself is piped).
REMOTE='
export VAULT_TOKEN="'"$ROOT"'"
SA=/var/run/secrets/kubernetes.io/serviceaccount
vault auth enable kubernetes 2>/dev/null || true
vault secrets enable -path=secret -version=2 kv 2>/dev/null || true
vault write auth/kubernetes/config kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" token_reviewer_jwt=@$SA/token kubernetes_ca_cert=@$SA/ca.crt disable_iss_validation=true
echo "path \"secret/data/fastapi/*\" { capabilities = [\"read\"] }" | vault policy write fastapi -
vault write auth/kubernetes/role/fastapi bound_service_account_names=fastapi-sa bound_service_account_namespaces=default policies=fastapi ttl=1h
vault kv put secret/fastapi/db username=fastapi password=changeme-in-prod
'
kx sh -c "$REMOTE"

echo ">> Bootstrap complete. fastapi role + secret/fastapi/db created."
