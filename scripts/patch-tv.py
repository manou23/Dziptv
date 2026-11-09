#!/usr/bin/env python3
"""Apply Android TV launcher support to a generated Capacitor Android project."""
from pathlib import Path
import re
import sys

manifest = Path("android/app/src/main/AndroidManifest.xml")
if not manifest.exists():
    print("AndroidManifest.xml not found. Run 'npx cap add android' first.", file=sys.stderr)
    sys.exit(1)

text = manifest.read_text(encoding="utf-8")
if "android.software.leanback" not in text:
    application = re.search(r"<application\\b", text)
    if not application:
        raise SystemExit("Could not locate <application> in AndroidManifest.xml")
    features = (
        '    <uses-feature android:name="android.software.leanback" android:required="false" />\\n'
        '    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />\\n'
    )
    text = text[:application.start()] + features + text[application.start():]

launcher = '<category android:name="android.intent.category.LAUNCHER" />'
leanback = '<category android:name="android.intent.category.LEANBACK_LAUNCHER" />'
if leanback not in text and launcher in text:
    text = text.replace(launcher, launcher + "\\n                " + leanback, 1)

# Many IPTV providers still expose HTTP endpoints. Enable cleartext for compatibility;
# the app warns users when they connect to an HTTP server.
app_tag = re.search(r"<application\\b[^>]*>", text)
if app_tag and "android:usesCleartextTraffic" not in app_tag.group(0):
    replacement = app_tag.group(0)[:-1] + ' android:usesCleartextTraffic="true">'
    text = text[:app_tag.start()] + replacement + text[app_tag.end():]

manifest.write_text(text, encoding="utf-8")
print("Android TV launcher compatibility configured.")
