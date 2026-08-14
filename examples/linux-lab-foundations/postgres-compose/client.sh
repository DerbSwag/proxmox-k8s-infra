#!/bin/sh
set -eu

: "${POSTGRES_DB:?POSTGRES_DB must be set}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD must be set}"

echo "Database is healthy; checking a client connection."
PGPASSWORD="$POSTGRES_PASSWORD" psql -h db -U postgres -d "$POSTGRES_DB" -c "SELECT 1;"
echo "Connection succeeded."

# Keep the example container available for inspection.
sleep infinity
