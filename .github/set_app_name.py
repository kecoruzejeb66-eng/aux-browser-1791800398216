import glob
import io
import os
import re

NAME_FILE = ".github/app_name.txt"
KIND_FILE = ".github/app_kind.txt"
ACTIVITY_SOURCE = ".github/MainActivity.kt"
MANIFEST = "android/app/src/main/AndroidManifest.xml"
LAUNCHER_QUERY = (
    '<intent><action android:name="android.intent.action.MAIN" />'
    '<category android:name="android.intent.category.LAUNCHER" /></intent>'
)


def read(path):
    if not os.path.exists(path):
        return ""
    with io.open(path, encoding="utf-8") as handle:
        return handle.read()


def write(path, text):
    with io.open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


def patch_manifest(name, kind):
    source = read(MANIFEST)
    if not source:
        print("AndroidManifest.xml not found; skipping.")
        return
    patched = source
    if name:
        safe = (
            name.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;")
        )
        patched = re.sub(r'android:label="[^"]*"', 'android:label="%s"' % safe, patched, count=1)
    # A launcher answers the Home button, so Android offers it as the phone's home screen.
    if kind == "launcher" and "category.HOME" not in patched:
        patched = re.sub(
            r'(<category android:name="android.intent.category.LAUNCHER"\s*/>)',
            r'\1\n                <category android:name="android.intent.category.HOME" />'
            r'\n                <category android:name="android.intent.category.DEFAULT" />',
            patched,
            count=1,
        )
    # Web pages and the app's own backend need the network; plain http sites need cleartext.
    if "android.permission.INTERNET" not in patched:
        patched = re.sub(
            r"<application\b",
            '<uses-permission android:name="android.permission.INTERNET" />\n    <application',
            patched,
            count=1,
        )
    if "usesCleartextTraffic" not in patched:
        patched = re.sub(
            r"<application\b", '<application android:usesCleartextTraffic="true"', patched, count=1
        )
    # Android 11+ hides other apps unless the manifest says which ones it needs to see.
    if "category.LAUNCHER\" /></intent>" not in patched:
        if "<queries>" in patched:
            patched = patched.replace("<queries>", "<queries>\n        " + LAUNCHER_QUERY, 1)
        else:
            patched = re.sub(
                r"<application\b",
                "<queries>" + LAUNCHER_QUERY + "</queries>\n    <application",
                patched,
                count=1,
            )
    write(MANIFEST, patched)
    print("Manifest ready (name: %s, kind: %s)" % (name or "default", kind or "app"))


def install_activity():
    body = read(ACTIVITY_SOURCE)
    if not body:
        print("No native activity supplied; keeping the default one.")
        return
    targets = glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True)
    if not targets:
        print("MainActivity.kt not found; skipping.")
        return
    match = re.search(r"^package\s+[\w.]+", read(targets[0]), re.M)
    package = match.group(0) if match else "package com.example.danger_world_app"
    write(targets[0], package + "\n\n" + body)
    print("Native activity installed.")


patch_manifest(read(NAME_FILE).strip(), read(KIND_FILE).strip())
install_activity()
