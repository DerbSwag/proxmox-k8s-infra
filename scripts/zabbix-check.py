#!/usr/bin/env python3
import os
import urllib.request, json

URL = os.environ.get("ZBX_URL", "http://localhost:30080/api_jsonrpc.php")
USER = os.environ.get("ZBX_USER")
PASSWORD = os.environ.get("ZBX_PASS")

if not USER or not PASSWORD:
    raise SystemExit("Set ZBX_USER and ZBX_PASS before running this script.")

def api(method, params, token=None):
    body = {"jsonrpc": "2.0", "method": method, "params": params, "id": 1}
    if token:
        body["auth"] = token
    data = json.dumps(body).encode()
    req = urllib.request.Request(URL, data=data, headers={"Content-Type": "application/json"})
    resp = urllib.request.urlopen(req)
    return json.loads(resp.read())["result"]

token = api("user.login", {"username": USER, "password": PASSWORD})

# Get all current problems
problems = api("problem.get", {"recent": True, "sortfield": "eventid", "sortorder": "DESC", "limit": 50}, token)

print(f"\n{'='*60}")
print(f"  Zabbix Problems ({len(problems)} active)")
print(f"{'='*60}\n")

for p in problems:
    severity = ["Not classified","Info","Warning","Average","High","Disaster"][int(p["severity"])]
    print(f"  [{severity:12}] {p['name']}")

# Get host availability
hosts = api("host.get", {"output": ["host", "name", "status"], "selectInterfaces": ["ip", "type", "available", "error"]}, token)

print(f"\n{'='*60}")
print(f"  Host Interface Status")
print(f"{'='*60}\n")

for h in hosts:
    for iface in h.get("interfaces", []):
        avail = {"0": "Unknown", "1": "Available", "2": "Unavailable"}.get(iface["available"], "?")
        itype = {"1": "Agent", "2": "SNMP", "3": "IPMI", "4": "JMX"}.get(iface["type"], "?")
        err = iface.get("error", "")
        status = "✅" if avail == "Available" else "🔴"
        line = f"  {status} {h['name']:20} {iface['ip']:18} {itype:6} {avail}"
        if err:
            line += f" — {err[:60]}"
        print(line)
