#!/usr/bin/env python3
"""Resolve the orchestrator coagent BY IDENTITY from a project's .env.

The deterministic, safety-critical piece of the /coagent skill: read
COAGENT_CHATGPT_URL from this project's .env and emit the URL + chat id, so Claude
drives the RIGHT coagent tab instead of guessing whatever ChatGPT tab is open
([[coagent]] §0 — the repeated "wrote to the wrong coagent" disaster, enforced in
code). Python stdlib only: a global skill must not depend on a project's npm deps.

Usage:
  python3 resolve-coagent.py                 # reads ./.env
  python3 resolve-coagent.py --env path/.env # explicit location
  python3 resolve-coagent.py --json          # machine-readable

Exit 0 + prints the URL/chat-id when resolved. Exit 1 with a clear message when
the var is missing/empty — that is the signal to ASK the user for the coagent id,
NEVER to adopt an open tab.
"""
import argparse
import json
import os
import re
import sys

VAR = "COAGENT_CHATGPT_URL"


def read_env_value(env_path, var):
    if not os.path.isfile(env_path):
        return None, f"no .env at {env_path}"
    try:
        with open(env_path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except OSError as exc:
        return None, f"cannot read {env_path}: {exc}"
    # last assignment wins; tolerate optional quotes and surrounding whitespace
    val = None
    for line in text.splitlines():
        m = re.match(rf"\s*(?:export\s+)?{re.escape(var)}\s*=\s*(.+?)\s*$", line)
        if m:
            val = m.group(1).strip().strip('"').strip("'")
    if not val:
        return None, f"{var} not set in {env_path}"
    return val, None


def chat_id(url):
    m = re.search(r"/c/([0-9a-fA-F-]+)", url or "")
    return m.group(1) if m else None


def main():
    ap = argparse.ArgumentParser(description="Resolve the coagent URL by identity from .env")
    ap.add_argument("--env", default=os.path.join(os.getcwd(), ".env"),
                    help="path to the .env (default: ./.env)")
    ap.add_argument("--json", action="store_true", help="emit JSON")
    args = ap.parse_args()

    url, err = read_env_value(args.env, VAR)
    if err:
        msg = (f"coagent NOT resolved: {err}. "
               f"ASK the user for the coagent chat URL/id — do NOT adopt an open ChatGPT tab ([[coagent]] §0).")
        if args.json:
            print(json.dumps({"ok": False, "error": msg}))
        else:
            print(msg, file=sys.stderr)
        return 1

    cid = chat_id(url)
    if args.json:
        print(json.dumps({"ok": True, "url": url, "chat_id": cid, "env": args.env}))
    else:
        print(f"coagent url: {url}")
        print(f"chat id:     {cid if cid else '(none — URL has no /c/<id>; verify it is a chat, not a GPT landing)'}")
        print(f"env:         {args.env}")
        print("\nVerify location.href contains this chat id JUST before writing ([[coagent]] §0.5).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
