#!/usr/bin/env python3
import subprocess
import os
import sys
import shutil
import argparse
import tempfile
from pathlib import Path

# --- Configuration ---

SUITE = {
    "01": [
        ["--edge", "10"],
        ["--edge", "25", "--tx", "5", "--ty", "5", "--tz", "5"]
    ],
    "02": [
        ["--length", "20", "--width", "20", "--height", "5"],
        ["--chamferSize", "2"],
        ["--filletRadius", "1.5"]
    ],
    "03": [
        ["--name", "gmlewis"],
        ["--name", "MoonBit", "--embossDepth", "2", "--length", "60"]
    ],
    "04": [
        ["--id", "5", "--od", "15", "--thickness", "2"],
        ["--id", "10", "--od", "12", "--thickness", "0.5", "--segments", "32"]
    ],
    "05": [
        ["--rows", "1", "--cols", "1", "--height", "20"],
        ["--rows", "2", "--cols", "1", "--text", "Gemini"]
    ],
    "06": [
        ["--count", "1"],
        ["--count", "3", "--height", "10", "--clickHeight", "1"]
    ]
}

# --- Utils ---

def find_occt():
    for bin_name in ["occt-draw", "DRAWEXE"]:
        if shutil.which(bin_name):
            return bin_name
    return None

def find_example_dir(num):
    root = Path(__file__).parent.parent
    examples_root = root / "examples"
    matches = list(examples_root.glob(f"{num}-*"))
    return matches[0] if matches else None

# --- Core Actions ---

def generate_step(num, args, output_path):
    root = Path(__file__).parent.parent
    run_script = root / "run-example.sh"
    cmd = [str(run_script), num] + args
    try:
        # Use subprocess.run to capture stdout directly to file
        with open(output_path, "w") as f:
            result = subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, text=True, check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"    FAILED: {e.stderr.strip()}")
        return False

def validate_step(occt_bin, step_path):
    draw_cmd = f"pload MODELING; pload XDE; testreadstep {step_path} s; checkshape s;"
    try:
        result = subprocess.run([occt_bin, "-b", "-c", draw_cmd], capture_output=True, text=True, check=True)
        if "This shape seems to be valid" in result.stdout:
            return True
        return False
    except subprocess.CalledProcessError:
        return False

def render_step(occt_bin, step_path, png_path):
    tcl_content = f"""
pload MODELING
pload VISUALIZATION
# Use offscreen initialization if supported
if {{ [catch {{vinit -offscreen}} ] }} {{
  vinit
}}
testreadstep {step_path} s
vdisplay s
vsetdispmode s 1
vfit
vviewparams -scale 0.9
vdump {png_path}
vclose ALL
exit
"""
    with tempfile.NamedTemporaryFile(suffix=".tcl", mode="w", delete=False) as tf:
        tf.write(tcl_content)
        tcl_path = tf.name

    try:
        # Attempt without -b first for macOS Cocoa context
        subprocess.run([occt_bin, "-f", tcl_path], capture_output=True, timeout=10)
    except:
        try:
            # Fallback to batch
            subprocess.run([occt_bin, "-b", "-f", tcl_path], capture_output=True, timeout=10)
        except:
            pass
    finally:
        os.unlink(tcl_path)
    
    return Path(png_path).exists()

def update_readme(example_dir, variants):
    readme_path = example_dir / "README.md"
    if not readme_path.exists():
        return

    content = readme_path.read_text()
    # Keep only content before the first '---'
    if "---" in content:
        content = content.split("---")[0].rstrip()

    new_section = "\n\n---\n"
    for i, (args, png_name) in enumerate(variants, 1):
        arg_str = " ".join(args)
        new_section += f"\n### Variant {i}\n\n"
        new_section += f"Command line: `./run-example.sh {example_dir.name[:2]} {arg_str}`\n\n"
        new_section += f"![Preview]({png_name})\n"
    
    readme_path.write_text(content + new_section + "\n")

# --- Main ---

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("target", help="Example number (e.g. 01) or 'all'")
    parser.add_argument("--validate", action="store_true", help="Run topology validation")
    parser.add_argument("--render", action="store_true", help="Generate PNG previews")
    parser.add_argument("--readme", action="store_true", help="Update README.md files")
    args = parser.parse_args()

    occt_bin = find_occt()
    if (args.validate or args.render) and not occt_bin:
        print("Error: OCCT (occt-draw or DRAWEXE) not found.")
        sys.exit(1)

    targets = SUITE.keys() if args.target == "all" else [args.target]
    
    for num in sorted(targets):
        example_dir = find_example_dir(num)
        if not example_dir:
            print(f"Skipping {num}: Directory not found")
            continue

        print(f"Processing Example {num} ({example_dir.name})...")
        
        configs = SUITE.get(num, [[]])
        variants_for_readme = []

        for i, config in enumerate(configs, 1):
            print(f"  [Set {i}] Args: {' '.join(config)}")
            
            step_file = Path(f"/tmp/example-{num}-{i}.step")
            png_name = f"preview-{i}.png"
            png_path = example_dir / png_name

            # 1. Generate
            if not generate_step(num, config, step_file):
                continue

            # 2. Validate
            if args.validate:
                if validate_step(occt_bin, step_file):
                    print("    Topology: OK")
                else:
                    print("    FAILED: Invalid topology")
                    continue

            # 3. Render
            if args.render:
                if render_step(occt_bin, step_file, png_path):
                    print(f"    Render: SUCCESS ({png_name})")
                else:
                    print("    Render: FAILED")

            variants_for_readme.append((config, png_name))

        # 4. Readme
        if args.readme:
            print(f"  Updating README.md...")
            update_readme(example_dir, variants_for_readme)

if __name__ == "__main__":
    main()
