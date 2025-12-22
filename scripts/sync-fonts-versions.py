#!/usr/bin/env python3
import json
import os
import glob
from pathlib import Path

def sync_versions():
    root_dir = Path(__file__).parent.parent
    root_mod_path = root_dir / "moon.mod.json"

    if not root_mod_path.exists():
        print(f"Error: {root_mod_path} not found.")
        return

    with open(root_mod_path, 'r') as f:
        root_mod = json.load(f)

    target_version = root_mod.get("deps", {}).get("gmlewis/fonts")
    if not target_version:
        print("Error: 'gmlewis/fonts' not found in root moon.mod.json deps.")
        return

    print(f"Target version: {target_version}")

    example_mods = glob.glob(str(root_dir / "examples/*/moon.mod.json"))
    
    for mod_path in example_mods:
        with open(mod_path, 'r') as f:
            content = f.read()
            try:
                mod_data = json.loads(content)
            except json.JSONDecodeError:
                print(f"Error decoding JSON in {mod_path}")
                continue

        changed = False
        deps = mod_data.get("deps", {})
        
        for dep_name in deps:
            if dep_name.startswith("gmlewis/fonts"):
                if isinstance(deps[dep_name], str) and deps[dep_name] != target_version:
                    print(f"Updating {dep_name} in {mod_path}: {deps[dep_name]} -> {target_version}")
                    deps[dep_name] = target_version
                    changed = True

        if changed:
            # We want to preserve 2-space indentation and the trailing newline if it exists
            # moon.mod.json usually has 2 spaces.
            with open(mod_path, 'w') as f:
                json.dump(mod_data, f, indent=2)
                f.write('\n')
            print(f"Updated {mod_path}")
        else:
            print(f"No changes needed for {mod_path}")

if __name__ == "__main__":
    sync_versions()
