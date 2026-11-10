#!/usr/bin/env python3
"""Builds dist/bank-tags-pro-<version>.zip from plugin/bank-tags-pro.

The ZIP contains the folder `bank-tags-pro/` (main.lua, plugin.json, src/...), ready to be
extracted into the client's dev_plugins folder. Run from the repository root:

    python scripts/package.py
"""
import json
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLUGIN_DIR = os.path.join(ROOT, "plugin", "bank-tags-pro")


def main():
    with open(os.path.join(PLUGIN_DIR, "plugin.json"), encoding="utf-8") as handle:
        manifest = json.load(handle)
    version = manifest.get("version", "dev")

    dist = os.path.join(ROOT, "dist")
    os.makedirs(dist, exist_ok=True)
    target = os.path.join(dist, "bank-tags-pro-{}.zip".format(version))

    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for folder, _, names in os.walk(PLUGIN_DIR):
            for name in sorted(names):
                path = os.path.join(folder, name)
                relative = os.path.relpath(path, os.path.dirname(PLUGIN_DIR))
                archive.write(path, relative.replace(os.sep, "/"))

    print("Wrote", os.path.relpath(target, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
