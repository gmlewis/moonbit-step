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
    "01": [["--edge", "10"], ["--edge", "25", "--tx", "5", "--ty", "5", "--tz", "5"]],
    "02": [["--length", "20", "--width", "20", "--height", "5"], ["--chamferSize", "2"], ["--filletRadius", "1.5"]],
    "03": [["--name", "gmlewis"], ["--name", "MoonBit", "--embossDepth", "2", "--length", "60"]],
    "04": [["--id", "5", "--od", "15", "--thickness", "2"], ["--id", "10", "--od", "12", "--thickness", "0.5", "--segments", "32"]],
    "05": [["--rows", "1", "--cols", "1", "--height", "20"], ["--rows", "2", "--cols", "1", "--text", "Gemini"]],
    "06": [["--count", "1"], ["--count", "3", "--height", "10", "--clickHeight", "1"]],
    "07": [["--diameter", "5", "--text", "USB"], ["--diameter", "10", "--text", "POWER", "--length", "30"]]
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

def generate_step(num, config, output_path):
    root = Path(__file__).parent.parent
    run_script = root / "run-example.sh"
    cmd = [str(run_script), num] + config
    try:
        with open(output_path, "w") as f:
            subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, text=True, check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"    FAILED: {e.stderr.strip()}")
        return False

def validate_step(occt_bin, step_path):
    draw_cmd = f"pload ALL; ReadStep D {step_path}; XGetOneShape s D; checkshape s;"
    try:
        result = subprocess.run([occt_bin, "-b", "-c", draw_cmd], capture_output=True, text=True, check=True)
        return "This shape seems to be valid" in result.stdout
    except:
        return False

def render_view(occt_bin, step_path, png_path, view_cmd, label):
    # Renders a single view to a PNG
    ppm_path = str(png_path).replace(".png", ".ppm")
    
    # We use ReadStep + XDisplay for colors.
    # vinit MUST come before XDisplay.
    draw_commands = f"""
pload ALL
vinit V -width 512 -height 512
vbackground -color WHITE
ReadStep D {step_path}
XDisplay D
vsetdispmode 1
{view_cmd}
vfit
# Shading and lighting
vlight clear
vlight add directional -dir -1 -1 -1 -color WHITE
vlight add ambient -color WHITE
vfit
vdrawtext L \"{label}\" -pos -240 240 0 -color BLACK -halign left -valign top
vdump {ppm_path}
vclose ALL
exit
"""
    try:
        subprocess.run([occt_bin], input=draw_commands, capture_output=True, text=True, timeout=30)
        if os.path.exists(ppm_path):
            subprocess.run(["sips", "-s", "format", "png", ppm_path, "--out", str(png_path)], capture_output=True, check=True)
            os.unlink(ppm_path)
            return True
    except Exception as e:
        print(f"      View '{label}' FAILED: {e}")
    return False

def render_variant(occt_bin, step_path, example_dir, idx):
    # Generate 4 separate PNGs for the variant
    views = [
        ("iso", "vviewparams -proj 1 -1 1 -up 0 0 1", "Isometric"),
        ("top", "vtop", "Top (XY)"),
        ("front", "vfront", "Front (XZ)"),
        ("side", "vleft", "Side (YZ)")
    ]
    
    results = {}
    for suffix, cmd, label in views:
        png_name = f"preview-{idx}-{suffix}.png"
        png_path = example_dir / png_name
        if render_view(occt_bin, step_path, png_path, cmd, label):
            results[suffix] = png_name
        else:
            results[suffix] = None
            
    return results

def update_readme(example_dir, variants_data):
    readme_path = example_dir / "README.md"
    if not readme_path.exists(): return
    
    # Keep original content before the marker
    content = readme_path.read_text().split("---")[0].rstrip()
    new_section = "\n\n---\n"
    
    for i, data in enumerate(variants_data, 1):
        config = data["config"]
        previews = data["previews"]
        arg_str = " ".join(config)
        
        new_section += f"\n### Variant {i}\n\n"
        new_section += f"Command line: `./run-example.sh {example_dir.name[:2]} {arg_str}`\n\n"
        
        # Create a 2x2 table for the 4 views
        new_section += "| Isometric | Top (XY) |\n|:---:|:---:|"
        new_section += f"\n| ![]({previews.get('iso', '')}) | ![]({previews.get('top', '')}) |\n"
        new_section += "| **Front (XZ)** | **Side (YZ)** |\n"
        new_section += f"| ![]({previews.get('front', '')}) | ![]({previews.get('side', '')}) |\n"
    
    readme_path.write_text(content + new_section + "\n")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("target", help="Example number or 'all'")
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--readme", action="store_true")
    args = parser.parse_args()

    occt_bin = find_occt()
    targets = SUITE.keys() if args.target == "all" else [args.target]
    
    for num in sorted(targets):
        example_dir = find_example_dir(num)
        if not example_dir: continue
        print(f"Processing Example {num}...")
        
        variants_processed = []
        for i, config in enumerate(SUITE[num], 1):
            print(f"  [Set {i}] Args: {' '.join(config)}")
            step_file = Path(f"/tmp/example-{num}-{i}.step")
            
            if not generate_step(num, config, step_file): continue
            
            if args.validate:
                if validate_step(occt_bin, step_file):
                    print("    Topology: OK")
                else:
                    print("    Topology: FAILED")
                    continue
            
            previews = {}
            if args.render:
                previews = render_variant(occt_bin, step_file, example_dir, i)
                if all(previews.values()):
                    print(f"    Render: SUCCESS (4 views)")
                else:
                    print(f"    Render: PARTIAL FAILURE")

            variants_processed.append({"config": config, "previews": previews})
            
        if args.readme:
            print(f"  Updating README.md...")
            update_readme(example_dir, variants_processed)

if __name__ == "__main__":
    main()