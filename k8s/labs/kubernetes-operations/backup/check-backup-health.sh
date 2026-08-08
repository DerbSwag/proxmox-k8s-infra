#!/bin/sh
set -eu
namespace=${1:?usage: $0 <namespace> <backup-cronjob> <reader-pod>}
cronjob=${2:?usage: $0 <namespace> <backup-cronjob> <reader-pod>}
reader=${3:?usage: $0 <namespace> <backup-cronjob> <reader-pod>}
kubectl -n "$namespace" get cronjob "$cronjob"
kubectl -n "$namespace" exec "$reader" -- sh -c 'find /backups -maxdepth 1 -type f -name "*.sql" -printf "%T@ %p\n" | sort -nr | head -1'
count=$(kubectl -n "$namespace" exec "$reader" -- sh -c 'find /backups -maxdepth 1 -type f -name "*.sql" | wc -l')
printf 'backup_count=%s\n' "$count"
