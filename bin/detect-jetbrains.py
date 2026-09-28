#!/usr/bin/env python3
"""Find the JetBrains IDE that currently has a given project open.

Prints the absolute path of the IDE's .app bundle, or nothing if the project
isn't open in any running IDE. Never raises: a detection failure just means no
IDE, and the caller falls back to a plain notification.

Detection combines two signals, because neither is sufficient alone:
  - recentProjects.xml records opened="true" per project, but entries go stale
    if the IDE was killed rather than quit.
  - the process list says which IDEs are actually running, but not what they
    have open.
Requiring both avoids pointing at an IDE that isn't there.
"""

import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

JETBRAINS_CONFIG = os.path.expanduser("~/Library/Application Support/JetBrains")
APP_DIRS = [os.path.expanduser("~/Applications"), "/Applications"]


def normalise(name):
    """'IntelliJ IDEA' and 'IntelliJIdea' must compare equal."""
    return re.sub(r"[^a-z0-9]", "", name.lower())


def running_app_bundles():
    """Map normalised app name -> absolute .app path, for running processes."""
    try:
        out = subprocess.run(
            ["ps", "-Ao", "comm="], capture_output=True, text=True, timeout=5
        ).stdout
    except Exception:
        return {}

    found = {}
    for line in out.splitlines():
        match = re.search(r"^(.*?/([^/]+)\.app)/Contents/MacOS/", line)
        if not match:
            continue
        path, name = match.group(1), match.group(2)
        if os.path.isdir(path):
            found.setdefault(normalise(name), path)
    return found


def locate_app(product):
    """Fall back to looking the IDE up on disk when ps gave a helper path."""
    target = normalise(product)
    for directory in APP_DIRS:
        try:
            entries = os.listdir(directory)
        except OSError:
            continue
        for entry in entries:
            if entry.endswith(".app") and normalise(entry[:-4]) == target:
                return os.path.join(directory, entry)
    return None


def version_key(product_dir):
    """Sort key so PhpStorm2026.2 beats PhpStorm2024.1."""
    digits = re.findall(r"(\d+)", product_dir)
    return [int(d) for d in digits] or [0]


def project_is_open(recent_projects_xml, project_path):
    home = os.path.expanduser("~")
    try:
        root = ET.parse(recent_projects_xml).getroot()
    except Exception:
        return False

    for entry in root.iter("entry"):
        key = entry.get("key")
        value = entry.find("value")
        if not key or value is None:
            continue
        info = value.find("RecentProjectMetaInfo")
        if info is None or info.get("opened") != "true":
            continue
        resolved = key.replace("$USER_HOME$", home).rstrip("/")
        if os.path.realpath(resolved) == project_path:
            return True
    return False


def main():
    if len(sys.argv) < 2:
        return 0
    project_path = os.path.realpath(sys.argv[1].rstrip("/"))

    running = running_app_bundles()
    if not running:
        return 0

    candidates = []
    try:
        product_dirs = os.listdir(JETBRAINS_CONFIG)
    except OSError:
        return 0

    for product_dir in product_dirs:
        recent = os.path.join(
            JETBRAINS_CONFIG, product_dir, "options", "recentProjects.xml"
        )
        if not os.path.isfile(recent):
            continue

        product = re.sub(r"[\d.]+$", "", product_dir)
        if not product:
            continue

        app = running.get(normalise(product))
        if app is None:
            continue

        if project_is_open(recent, project_path):
            candidates.append((version_key(product_dir), product, app))

    if not candidates:
        return 0

    candidates.sort(reverse=True)
    _, product, app = candidates[0]
    print(app if os.path.isdir(app) else (locate_app(product) or ""))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)
