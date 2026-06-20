#!/usr/bin/env python3
"""Suppress noise alerts by disabling triggers for non-essential Windows services"""
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
        print(f"  ERROR: {result['error']['data']}")
        return None
    return result.get("result")

token = api("user.login", {"username": "Admin", "password": "zabbix"})
print("✅ Logged in\n")

# Find triggers with noise service names and disable them
NOISE = ["GoogleUpdater", "AppXSvc", "igccservice", "Intel(R) Platform License", "webthreatdefusersvc"]

triggers = api("trigger.get", {
    "output": ["triggerid", "description", "status"],
    "filter": {"value": "1"},  # only PROBLEM state
    "limit": 200
}, token)

disabled = 0
for t in triggers:
    if any(kw in t["description"] for kw in NOISE):
        api("trigger.update", {"triggerid": t["triggerid"], "status": "1"}, token)  # 1 = disabled
        disabled += 1
        print(f"  ✅ Disabled: {t['description'][:70]}")

print(f"\n  Total disabled: {disabled} noise triggers")
