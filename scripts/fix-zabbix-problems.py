#!/usr/bin/env python3
"""Fix Zabbix problems: set SNMP macro, suppress noise alerts"""
import urllib.request, json, sys

URL = "http://localhost:30080/api_jsonrpc.php"
REQ_ID = 0

def api(method, params, token=None):
    global REQ_ID
    REQ_ID += 1
    body = {"jsonrpc": "2.0", "method": method, "params": params, "id": REQ_ID}
    if token:
        body["auth"] = token
    data = json.dumps(body).encode()
    req = urllib.request.Request(URL, data=data, headers={"Content-Type": "application/json"})
    resp = urllib.request.urlopen(req)
    result = json.loads(resp.read())
    if "error" in result:
        print(f"  ERROR: {result['error']}")
        return None
    return result.get("result")

# Login
token = api("user.login", {"username": "Admin", "password": "zabbix"})
if not token:
    sys.exit(1)
print("✅ Logged in to Zabbix API\n")

# === 1. Set {$SNMP_COMMUNITY} global macro ===
print("=" * 50)
print("  [1] Setting {$SNMP_COMMUNITY} macro")
print("=" * 50)

# Check if macro exists
macros = api("usermacro.get", {"globalmacro": True, "search": {"macro": "{$SNMP_COMMUNITY}"}}, token)
if macros:
    # Update existing
    result = api("usermacro.updateglobal", {"globalmacroid": macros[0]["globalmacroid"], "value": "public"}, token)
    print(f"  ✅ Updated global macro {{$SNMP_COMMUNITY}} = public")
else:
    # Create new
    result = api("usermacro.createglobal", {"macro": "{$SNMP_COMMUNITY}", "value": "public"}, token)
    print(f"  ✅ Created global macro {{$SNMP_COMMUNITY}} = public")

# === 2. Suppress noise alerts ===
print(f"\n{'=' * 50}")
print("  [2] Suppressing noise service alerts")
print("=" * 50)

# Services to suppress via host macros on Windows hosts
NOISE_SERVICES = [
    "GoogleUpdaterService",
    "GoogleUpdaterInternalService",
    "AppXSvc",
    "igccservice",
    "Intel(R) Platform License Manager Service",
    "webthreatdefusersvc",
]

# Get Windows hosts
hosts = api("host.get", {"output": ["hostid", "name"], "search": {"name": "SERVER"}, "searchWildcardsEnabled": True}, token)
windows_hosts = [h for h in hosts if "SERVER" in h["name"]]

# For each Windows host, set service filter macro
for host in windows_hosts:
    # Check existing macro
    existing = api("usermacro.get", {"hostids": host["hostid"], "search": {"macro": "{$SERVICE.FILTER.NOT_REGEXP}"}}, token)
    filter_value = "|".join(NOISE_SERVICES)

    if existing:
        api("usermacro.update", {"hostmacroid": existing[0]["hostmacroid"], "value": filter_value}, token)
    else:
        api("usermacro.create", {"hostid": host["hostid"], "macro": "{$SERVICE.FILTER.NOT_REGEXP}", "value": filter_value}, token)
    print(f"  ✅ {host['name']}: set service filter")

# === 3. Close noise problems (acknowledge + close) ===
print(f"\n{'=' * 50}")
print("  [3] Closing noise problems")
print("=" * 50)

problems = api("problem.get", {"recent": True, "output": ["eventid", "name"], "limit": 100}, token)
noise_keywords = ["GoogleUpdater", "AppXSvc", "igccservice", "Intel(R) Platform License", "webthreatdefusersvc"]

closed = 0
for p in problems:
    if any(kw in p["name"] for kw in noise_keywords):
        api("event.acknowledge", {"eventids": p["eventid"], "action": 1, "message": "Suppressed: noise service alert"}, token)
        closed += 1

print(f"  ✅ Acknowledged {closed} noise alerts")

print(f"\n{'=' * 50}")
print("  Done!")
print("=" * 50)
