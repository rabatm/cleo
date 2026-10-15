#!/usr/bin/env python3
"""Teste l'endpoint officieux /api/oauth/usage d'Anthropic avec le jeton
OAuth de Claude Code stocké dans le trousseau macOS (rien n'est imprimé
sauf la réponse de l'endpoint, qui ne contient aucun secret)."""
import json
import subprocess
import sys
import urllib.request

# 1. Récupérer le JSON d'identifiants depuis le trousseau
raw = subprocess.run(
    ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
    capture_output=True, text=True)
if raw.returncode != 0:
    print("AUCUN TROUSSEAU:", raw.stderr.strip()[:120])
    sys.exit(0)

creds = json.loads(raw.stdout)
oauth = creds.get("claudeAiOauth", {})
token = oauth.get("accessToken")
print("Champs du trousseau:", sorted(creds.keys()))
print("Champs oauth:", sorted(oauth.keys()))
print("subscriptionType:", oauth.get("subscriptionType"))
print("Token présent:", bool(token))

if not token:
    sys.exit(0)

# 2. Interroger l'endpoint usage
req = urllib.request.Request(
    "https://api.anthropic.com/api/oauth/usage",
    headers={
        "Authorization": f"Bearer {token}",
        "anthropic-beta": "oauth-2025-04-20",
    })
try:
    with urllib.request.urlopen(req, timeout=15) as r:
        print("HTTP", r.status)
        print(json.dumps(json.loads(r.read().decode()), indent=2))
except urllib.error.HTTPError as e:
    print("HTTP", e.code, e.reason)
    body = e.read().decode()[:300]
    print(body)
