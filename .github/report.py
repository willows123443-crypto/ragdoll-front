#!/usr/bin/env python3
"""Collects errors from the Godot logs and posts them as a comment on the report issue."""
import os, re, subprocess

def read(p):
    try:
        return open(p, errors="replace").read()
    except OSError:
        return ""

logs = {"import": read("import.log"), "test": read("test.log"), "export": read("export.log")}
errors = []
seen = set()
for name, text in logs.items():
    lines = text.splitlines()
    for i, ln in enumerate(lines):
        if re.search(r"(SCRIPT ERROR|Parse Error|^ERROR|ERROR:|Invalid call|Invalid access|Invalid get|Invalid set|Nonexistent function|Identifier .* not declared|Cannot|Failed|EXIT CODE)", ln):
            ctx = [ln.strip()]
            for j in range(i + 1, min(i + 3, len(lines))):
                if lines[j].strip().startswith("at:") or lines[j].startswith("   "):
                    ctx.append(lines[j].strip())
            key = re.sub(r"\d+\.\d+", "", " | ".join(ctx))
            if key in seen:
                continue
            seen.add(key)
            errors.append("[%s] %s" % (name, "\n    ".join(ctx)))

autotest = [l for l in logs["test"].splitlines() if l.startswith("AUTOTEST")]
built = os.path.exists("build/web/index.html")
sha = os.environ.get("GITHUB_SHA", "")[:7]
msg = os.popen("git log -1 --pretty=%s").read().strip()

body = ["### Build `%s`: %s" % (sha, msg), ""]
body.append("- Web build: **%s**" % ("OK" if built else "FAILED"))
body.append("- Autotest finished: **%s**" % ("yes" if "AUTOTEST done" in logs["test"] else "NO"))
body.append("- Errors found: **%d**" % len(errors))
body.append("")
if autotest:
    body += ["```", *autotest, "```", ""]
if errors:
    body.append("<details><summary>Errors</summary>\n\n```")
    body += errors[:80]
    if len(errors) > 80:
        body.append("... and %d more" % (len(errors) - 80))
    body.append("```\n</details>")
text = "\n".join(body)
print(text)
TITLE = "Automatic build reports"
out = subprocess.run(["gh", "issue", "list", "--state", "all", "--search", TITLE + " in:title", "--json", "number,title"],
                     capture_output=True, text=True).stdout
import json
num = None
try:
    for it in json.loads(out or "[]"):
        if it["title"] == TITLE:
            num = str(it["number"])
except ValueError:
    pass
if num is None:
    made = subprocess.run(["gh", "issue", "create", "--title", TITLE, "--body",
                    "Each push to main builds the game, runs an automatic headless test on all three maps, and posts the results here.\n\nPlay: https://%s.github.io/%s/" % tuple(os.environ.get("GITHUB_REPOSITORY", "x/y").split("/"))], capture_output=True, text=True).stdout
    m = re.search(r"/issues/(\d+)", made)
    if m:
        num = m.group(1)
if num is None:
    num = "1"
if num:
    subprocess.run(["gh", "issue", "comment", num, "--body", text[:60000]], check=False)
