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
        with open(output_path, "w") as f:
            subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, text=True, check=True)
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
    ppm_path = str(png_path).replace(".png", ".ppm")
    # Improved rendering script:
    # 1. Bigger window (800x800)
    # 2. White background
    # 3. Shaded mode
    # 4. Correct fit without overriding scale
    draw_commands = f"""
pload ALL
vinit View1 -width 800 -height 800
vbackground -color WHITE
testreadstep {step_path} s
vdisplay s
vsetdispmode s 1
vfit
vdump {ppm_path}
vclose ALL
exit
"""
    try:
        # Using pipe to DRAWEXE (no -b) is most reliable for Cocoa on macOS
        subprocess.run(
            [occt_bin],
            input=draw_commands,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if os.path.exists(ppm_path):
            # Convert PPM to real PNG using macOS built-in sips
            subprocess.run(["sips", "-s", "format", "png", ppm_path, "--out", str(png_path)], 
                           capture_output=True, check=True)
            os.unlink(ppm_path)
            return True
    except Exception as e:
        print(f"    FAILED: {e}")
    
    return Path(png_path).exists()

def update_readme(example_dir, variants):
    readme_path = example_dir / "README.md"
    if not readme_path.exists():
        return

    lines = readme_path.read_text().splitlines()
    clean_lines = []
    for line in lines:
        if line.strip() == "---":
            break
        clean_lines.append(line)
    
    content = "\n".join(clean_lines).rstrip()
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