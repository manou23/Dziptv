#!/usr/bin/env python3
"""Validate embedded JavaScript before packaging the Android application."""
from pathlib import Path
import re
import subprocess
import tempfile

html = Path("www/index.html").read_text(encoding="utf-8")
scripts = re.findall(r"<script(?![^>]*\\bsrc=)[^>]*>(.*?)</script>", html, flags=re.I | re.S)
if not scripts:
    raise SystemExit("No inline JavaScript blocks found in www/index.html")

for index, source in enumerate(scripts, start=1):
    with tempfile.NamedTemporaryFile("w", suffix=".js", encoding="utf-8", delete=False) as handle:
        handle.write(source)
        filename = handle.name
    subprocess.run(["node", "--check", filename], check=True)
    Path(filename).unlink(missing_ok=True)

print(f"Web check passed: {len(scripts)} inline JavaScript block(s) are syntactically valid.")
