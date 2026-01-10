#!/usr/bin/env python3
import json
import os
import glob
from pathlib import Path
import stat

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

    example_mods = glob.glob(str(root_dir / "examples/*/moon.mod.json"))
    
    for mod_path_str in example_mods:
        mod_path = Path(mod_path_str)
        with open(mod_path, 'r') as f:
            content = f.read()
            try:
                mod_data = json.loads(content)
            except json.JSONDecodeError:
                print(f"Error decoding JSON in {mod_path}")
                continue

        mod_changed = False
        deps = mod_data.get("deps", {})
        
        # 1. Update font versions
        for dep_name in deps:
            if dep_name.startswith("gmlewis/fonts"):
                if isinstance(deps[dep_name], str) and deps[dep_name] != target_version:
                    deps[dep_name] = target_version
                    mod_changed = True

        # 2. Prepare update.sh content
        update_sh_path = mod_path.parent / "update.sh"
        update_sh_lines = ["#!/bin/bash -ex"]
        for dep_name, dep_val in deps.items():
            if isinstance(dep_val, str):
                update_sh_lines.append(f"moon add --no-update {dep_name}")
        
        update_sh_lines.append("moon install")
        update_sh_lines.append("moon check --target native")
        update_sh_content = "\n".join(update_sh_lines) + "\n"

        update_sh_changed = False
        if not update_sh_path.exists():
            update_sh_changed = True
        else:
            with open(update_sh_path, 'r') as f:
                if f.read() != update_sh_content:
                    update_sh_changed = True

        # 3. Apply changes
        if mod_changed or update_sh_changed:
            if mod_changed:
                with open(mod_path, 'w') as f:
                    json.dump(mod_data, f, indent=2)
                    f.write('\n')
            
            if update_sh_changed:
                with open(update_sh_path, 'w') as f:
                    f.write(update_sh_content)
                # make it executable
                st = os.stat(update_sh_path)
                os.chmod(update_sh_path, st.st_mode | stat.S_IEXEC)
            
            print(f"Updated {mod_path.parent}")

if __name__ == "__main__":
    sync_versions()