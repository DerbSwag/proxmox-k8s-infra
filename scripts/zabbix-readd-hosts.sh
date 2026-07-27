#!/usr/bin/env bash
# Re-add all monitored hosts to a fresh Zabbix via API.
# Used during DR (2026-06-16) after Zabbix DB was lost.
# Run from a host that can reach the Zabbix web NodePort.
#   ZBX_URL=http://192.0.2.10:30080 ZBX_USER=<user> ZBX_PASS=<password> ./scripts/zabbix-readd-hosts.sh
#
# Host inventory source of truth: README.md "Monitored Hosts" table.
# Templates assumed present in a default Zabbix 7.0 install:
#   Linux by Zabbix agent (10001), Windows by Zabbix agent (10081), Proxmox VE by HTTP (10517)
set -euo pipefail

ZBX_URL="${ZBX_URL:-http://localhost:30080}"
ZBX_USER="${ZBX_USER:?set ZBX_USER}"
ZBX_PASS="${ZBX_PASS:?set ZBX_PASS}"
API="$ZBX_URL/api_jsonrpc.php"
H='Content-Type: application/json'
call() { curl -s -X POST "$API" -H "$H" -d "$1"; }

TOKEN=$(call "{\"jsonrpc\":\"2.0\",\"method\":\"user.login\",\"params\":{\"username\":\"$ZBX_USER\",\"password\":\"$ZBX_PASS\"},\"id\":1}" | sed -E 's/.*"result":"([^"]+)".*/\1/')
echo "auth ok"

group_id() {
  local name="$1" gid
  gid=$(call "{\"jsonrpc\":\"2.0\",\"method\":\"hostgroup.get\",\"params\":{\"output\":[\"groupid\"],\"filter\":{\"name\":[\"$name\"]}},\"auth\":\"$TOKEN\",\"id\":3}" | sed -E 's/.*"groupid":"([0-9]+)".*/\1/')
  echo "$gid" | grep -qE '^[0-9]+$' || gid=$(call "{\"jsonrpc\":\"2.0\",\"method\":\"hostgroup.create\",\"params\":{\"name\":\"$name\"},\"auth\":\"$TOKEN\",\"id\":4}" | sed -E 's/.*"groupids":\["([0-9]+)".*/\1/')
  echo "$gid"
}
GID_LINUX=$(group_id "Linux servers"); GID_WIN=$(group_id "Windows PCs")
GID_HV=$(group_id "Hypervisors");      GID_camera=$(group_id "camera")

add_agent() { # name ip groupid templateid
  local tpl=""; [ -n "$4" ] && tpl=",\"templates\":[{\"templateid\":\"$4\"}]"
  call "{\"jsonrpc\":\"2.0\",\"method\":\"host.create\",\"params\":{\"host\":\"$1\",\"interfaces\":[{\"type\":1,\"main\":1,\"useip\":1,\"ip\":\"$2\",\"dns\":\"\",\"port\":\"10050\"}],\"groups\":[{\"groupid\":\"$3\"}]$tpl},\"auth\":\"$TOKEN\",\"id\":5}" >/dev/null && echo "added $1 ($2)"
}
add_snmp() { # name ip
  call "{\"jsonrpc\":\"2.0\",\"method\":\"host.create\",\"params\":{\"host\":\"$1\",\"interfaces\":[{\"type\":2,\"main\":1,\"useip\":1,\"ip\":\"$2\",\"dns\":\"\",\"port\":\"161\",\"details\":{\"version\":2,\"community\":\"{\$SNMP_COMMUNITY}\"}}],\"groups\":[{\"groupid\":\"$GID_camera\"}],\"macros\":[{\"macro\":\"{\$SNMP_COMMUNITY}\",\"value\":\"public\"}]},\"auth\":\"$TOKEN\",\"id\":6}" >/dev/null && echo "added $1 ($2)"
}

add_agent "k8s-master"    "192.0.2.10" "$GID_LINUX" "10001"
add_agent "k8s-worker-01" "192.0.2.11" "$GID_LINUX" "10001"
add_agent "k8s-worker-02" "192.0.2.12" "$GID_LINUX" "10001"
add_agent "APP-SERVER-01"   "203.0.113.10"    "$GID_WIN"   "10081"
add_agent "APP-SERVER-02"  "203.0.113.23"    "$GID_WIN"   "10081"
add_agent "APP-SERVER-03"      "198.51.100.9"   "$GID_WIN"   "10081"
add_agent "APP-SERVER-04"    "198.51.100.11"  "$GID_WIN"   "10081"
add_agent "APP-SERVER-05"   "198.51.100.13"  "$GID_WIN"   "10081"
add_agent "hypervisor-01"         "192.0.2.1"  "$GID_HV"    ""
add_agent "hypervisor-02"         "192.0.2.2"  "$GID_HV"    ""
add_snmp  "CAMERA-01"       "203.0.113.9"
add_snmp  "CAMERA-02"       "192.0.2.x"
add_snmp  "CAMERA-03"       "198.51.100.139"
add_snmp  "CAMERA-04"       "192.0.2.x"

echo "Done. NOTE: after this, re-apply the GoogleUpdater suppression macro on the"
echo "'Windows by Zabbix agent' template (\$SERVICE.NAME.NOT_MATCHES) — see docs/zabbix-notes.md."
