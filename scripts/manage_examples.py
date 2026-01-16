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
    "02": [["--length", "20", "--width", "20", "--height", "5"], ["--chamferSize", "4"], ["--filletRadius", "1.5"]],
    "03": [
        ["--name", "gmlewis", "--emboss"],
        ["--name", "MoonBit", "--embossDepth", "2", "--length", "60", "--emboss"],
        ["--name", "gmlewis"],
    ],
    "04": [["--id", "5", "--od", "15", "--thickness", "2"], ["--id", "10", "--od", "12", "--thickness", "0.5", "--segments", "32"]],
    "05": [["--rows", "1", "--cols", "1", "--height", "20"], ["--rows", "2", "--cols", "1", "--text", "Gemini"]],
    "06": [["--count", "1"], ["--count", "3", "--height", "10", "--clickHeight", "1"]],
    "07": [["--diameter", "5", "--text", "USB"], ["--diameter", "10", "--text", "POWER", "--length", "30"]],
    "08": [["--stepCount", "3"], ["--stepCount", "5", "--interference", "0.2", "--interferenceStep", "0.2"]],
    "09": [["--baseWidth", "60", "--baseLength", "80"], ["--dovetailAngle", "20", "--dovetailHeight", "10"], ["--clearance", "0.5"]],
    "10": [["--sides", "6", "--holeSides", "6"], ["--sides", "5", "--holeSides", "3", "--diameter", "25"], ["--sides", "8", "--holeSides", "4", "--holeRotation", "45", "--diameter", "40"]],
    "11": [["--rows", "2", "--cols", "4"], ["--rows", "1", "--cols", "5", "--spacing", "8.5", "--tolerance", "0.05"], ["--rows", "3", "--cols", "3", "--spacing", "15", "--height", "25"]],
    "12": [["--nocage", "--numPairs", "2", "--wireGap", "0.5", "--vertTurns", "1"],
           ["--nocoil", "--nowires", "--nosupport"],
           []],
    "13": [["--length", "60", "--width", "70"], ["--length", "100", "--width", "80", "--height", "15"], ["--width", "50", "--height", "12"]],
    "14": [["--length", "100"], ["--length", "150", "--width", "50"], ["--length", "80", "--height", "12"]],
    "15": [["--boltDiameter", "8", "--clearance", "0.1"], ["--boltDiameter", "10", "--interference", "0.1", "--clearanceStep", "0.1", "--stepCount", "3"]],
    "16": [["--pinDiameter", "5", "--clearance", "0.05"], ["--pinDiameter", "10", "--interference", "0.1", "--clearanceStep", "0.05", "--stepCount", "4"]],
    "17": [["--thickness", "2", "--hingeWidth", "15"], ["--width", "30", "--slotLength", "5", "--numRows", "10"]],
    "18": [["--width", "60", "--length", "80", "--height", "30"], ["--wallThickness", "3", "--filletRadius", "10", "--bossOD", "10"]],
    "19": [["--width", "85", "--length", "75"], ["--width", "100", "--length", "60", "--slotLength", "20"]],
    "20": [["--standoffHeight", "6"], ["--standoffHeight", "12", "--standoffOD", "8", "--frameThickness", "5"]],
    "21": [["--width", "54.5", "--height", "8"], ["--width", "35", "--height", "6", "--armThickness", "2"]],
    "22": [["--rows", "2", "--cols", "2"], ["--rows", "1", "--cols", "4", "--spacing", "20", "--anchorWidth", "8"]],
    "23": [["--innerDiameter", "8", "--panelThickness", "2"], ["--innerDiameter", "12", "--split"]],
    "24": [["--angle", "15", "--seatDepth", "10"], ["--angle", "0", "--holeDiameter", "12", "--height", "60"]],
    "25": [["--angles", "15,22.5,30,45"], ["--size", "80", "--angles", "36,54"]],
    "26": [["--armLength", "250"], ["--baseDiameter", "180", "--armLength", "400", "--armWidth", "50"]],
    "27": [["--length", "60"], ["--width", "42", "--height", "12"]],
    "28": [["--phoneThickness", "10"], ["--viewAngle", "30", "--width", "100"]],
    "29": [["--width", "40", "--armLength", "80"], ["--hookHeight", "40", "--thickness", "8"]],
    "30": [["--length", "150", "--width", "50", "--height", "40"], ["--length", "300", "--width", "80", "--height", "60", "--thickness", "4"]],
    "31": [["--rows", "1", "--cols", "5", "--labelPrefix", "P"], ["--rows", "2", "--cols", "3", "--cellSize", "40", "--magnetDiameter", "12", "--labelPrefix", "T"]],
    "32": [["--baseLength", "100", "--armHeight", "150"], ["--axleDia", "30", "--armWidth", "40", "--armBaseThickness", "50", "--armTopThickness", "35", "--holeSpacing", "80", "--baseLength", "110"]],
    "33": [["--bodyLength", "45", "--bodyWidth", "35"], ["--wallThickness", "2", "--filamentClearance", "0.8", "--switchWidth", "15"]],
    "34": [["--length", "50", "--width", "25"], ["--height", "20", "--beltThickness", "2.0", "--boltDia", "5.2"]],
    "35": [["--railWidth", "12", "--railHeight", "8"], ["--railWidth", "15", "--railHeight", "10", "--thickness", "15"]],
    "36": [["--petals", "12"], ["--petals", "8", "--tx", "50"]],
    "37": [["--diameter", "25.4", "--type", "cap"], ["--diameter", "25.4", "--type", "plug", "--topThickness", "5"], ["--diameter", "50", "--wall", "1.2", "--height", "20"]],
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

def generate_bpy(num, config, bpy_path):
    root = Path(__file__).parent.parent
    run_script = root / "run-example.sh"
    cmd = [str(run_script), num] + config + ["--bpy", str(bpy_path)]
    try:
        subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"    FAILED: {e.stderr.strip()}")
        return False

def validate_bpy(root, bpy_path, blend_path):
    validator = root / "scripts" / "validate-bpy.py"
    cmd = [str(validator), "--blend", str(blend_path), str(bpy_path)]
    try:
        subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"    Blender validation FAILED: {e.stderr.strip()}")
        return False

def validate_step(step_path):
    scripts_dir = Path(__file__).parent
    validator = scripts_dir / "validate_with_occt.sh"
    cmd = [str(validator), str(step_path)]
    try:
        subprocess.run(cmd, capture_output=True, text=True, check=True)
        return True
    except subprocess.CalledProcessError:
        return False

def render_view(occt_bin, step_path, png_path, view_cmd):
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
        print(f"      View FAILED: {e}")
    return False

def composite_views(inkscape_bin, views_dict, output_png):
    # Composites 4 PNGs into one using an SVG template and inkscape
    template_path = Path(__file__).parent / "view_template.svg"
    if not template_path.exists():
        print(f"      SVG template not found at {template_path}")
        return False

    template_content = template_path.read_text()

    # Replace placeholders with absolute paths to the rendered PNGs
    # In the template, IDs are iso_img, top_img, front_img, side_img
    # and they have xlink:href="iso.png" etc.
    replacements = {
        'xlink:href="iso.png"': f'xlink:href="{views_dict["iso"]}"',
        'xlink:href="top.png"': f'xlink:href="{views_dict["top"]}"',
        'xlink:href="front.png"': f'xlink:href="{views_dict["front"]}"',
        'xlink:href="side.png"': f'xlink:href="{views_dict["side"]}"',
    }

    for old, new in replacements.items():
        template_content = template_content.replace(old, new)

    with tempfile.NamedTemporaryFile(suffix=".svg", delete=False) as tmp_svg:
        tmp_svg.write(template_content.encode("utf-8"))
        tmp_svg_path = tmp_svg.name

    try:
        cmd = [inkscape_bin, "--export-filename=" + str(output_png), tmp_svg_path]
        subprocess.run(cmd, capture_output=True, check=True)
        return True
    except Exception as e:
        print(f"      Compositing FAILED: {e}")
        return False
    finally:
        if os.path.exists(tmp_svg_path):
            os.unlink(tmp_svg_path)

def render_variant(occt_bin, inkscape_bin, step_path, example_dir, idx):
    # Generate 4 separate PNGs and composite them
    views = [
        ("iso", "vviewparams -proj 1 -1 1 -up 0 0 1"),
        ("top", "vtop"),
        ("front", "vfront"),
        ("side", "vleft")
    ]

    temp_pngs = {}
    # Use a temp directory for the 4 views
    with tempfile.TemporaryDirectory() as tmpdir:
        for suffix, cmd in views:
            png_path = Path(tmpdir) / f"{suffix}.png"
            if render_view(occt_bin, step_path, png_path, cmd):
                temp_pngs[suffix] = str(png_path)
            else:
                print(f"      Failed to render view {suffix}")
                return None

        final_png_name = f"preview-{idx}.png"
        final_png_path = example_dir / final_png_name
        if composite_views(inkscape_bin, temp_pngs, final_png_path):
            return final_png_name

    return None

def update_readme(example_dir, variants_data):
    readme_path = example_dir / "README.md"
    if not readme_path.exists(): return

    # Keep original content before the marker
    content = readme_path.read_text().split("---")[0].rstrip()
    new_section = "\n\n---\n"

    for i, data in enumerate(variants_data, 1):
        config = data["config"]
        preview = data["preview"]
        arg_str = " ".join(config)

        num_part = example_dir.name.split("-")[0]
        new_section += f"\n### Variant {i}\n\n"
        new_section += f"Command line: `./run-example.sh {num_part} {arg_str}`\n\n"

        if preview:
            new_section += f"![]({preview})\n"
        else:
            new_section += "_[Render Failed]_\n"

    readme_path.write_text(content + new_section + "\n")

def main():
    root = Path(__file__).parent.parent

    # Run moon check first
    print("Running 'moon check --target native'...")
    try:
        subprocess.run(["moon", "check", "--target", "native"], cwd=root, check=True, capture_output=True, text=True)
        print("  Check: OK")
    except subprocess.CalledProcessError as e:
        print("\nERROR: 'moon check --target native' failed. Please fix the following errors before running this script again:\n")
        print(e.stdout)
        print(e.stderr)
        sys.exit(1)

    # Run test-all.sh
    print("Running './test-all.sh'...")
    try:
        result = subprocess.run(["./test-all.sh"], cwd=root, check=True, capture_output=True, text=True)
        if "failed: 0" in result.stdout:
            print("  Tests: OK")
        else:
            print("\nERROR: './test-all.sh' reported failures:\n")
            # Show only the summary line
            lines = result.stdout.splitlines()
            for line in lines:
                if "Total tests:" in line:
                    print(line)
            sys.exit(1)
    except subprocess.CalledProcessError as e:
        print("\nERROR: './test-all.sh' failed to execute correctly:\n")
        print(e.stdout)
        print(e.stderr)
        sys.exit(1)

    parser = argparse.ArgumentParser()
    parser.add_argument("target", nargs="?", default="all", help="Example number or 'all'")
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--readme", action="store_true")
    parser.add_argument("--bpy", action="store_true")
    args = parser.parse_args()

    occt_bin = find_occt()
    inkscape_bin = shutil.which("inkscape")

    if args.render and not inkscape_bin:
        print("Error: 'inkscape' not found in PATH. Required for rendering.")
        sys.exit(1)

    targets = sorted(SUITE.keys()) if args.target == "all" else [args.target]
    bpy_output_dir = root / "bpy-out"
    if args.bpy:
        bpy_output_dir.mkdir(parents=True, exist_ok=True)

    for num in targets:
        # Handle non-padded input (e.g., "3" -> "03")
        padded_num = num.zfill(2)
        if padded_num not in SUITE:
            print(f"Example {num} (padded: {padded_num}) not found in SUITE.")
            sys.exit(1)

        example_dir = find_example_dir(padded_num)
        if not example_dir:
            print(f"Example directory for {padded_num} not found.")
            sys.exit(1)

        print(f"Processing Example {padded_num}...")

        # Cleanup old individual views if they exist
        if args.render:
            for old_img in example_dir.glob("preview-*-*.png"):
                # don't delete the new ones (preview-1.png etc)
                if "-" in old_img.name.split(".")[0].split("-", 1)[1]:
                    old_img.unlink()

        variants_processed = []
        for i, config in enumerate(SUITE[padded_num], 1):
            print(f"  [Set {i}] Args: {' '.join(config)}")
            if args.bpy:
                base_name = f"example-{padded_num}-{i}"
                bpy_file = bpy_output_dir / f"{base_name}.py"
                blend_file = bpy_output_dir / f"{base_name}.blend"
                print(f"    Generating {base_name}.py ...")
                if not generate_bpy(padded_num, config, bpy_file):
                    sys.exit(1)
                print(f"    Validating {base_name}.py and generating {base_name}.blend ...")
                if not validate_bpy(root, bpy_file, blend_file):
                    sys.exit(1)
                variants_processed.append({"config": config, "preview": None})

            # Generate and validate STEP files
            step_file = Path(f"/tmp/example-{padded_num}-{i}.step")

            if not generate_step(padded_num, config, step_file):
                sys.exit(1)

            if args.validate:
                if validate_step(step_file):
                    print("    Topology: OK")
                else:
                    print("    Topology: FAILED")
                    sys.exit(1)

            preview = None
            if args.render:
                preview = render_variant(occt_bin, inkscape_bin, step_file, example_dir, i)
                if preview:
                    print(f"    Render: SUCCESS ({preview})")
                else:
                    print(f"    Render: FAILED")
                    sys.exit(1)

            variants_processed.append({"config": config, "preview": preview})

        if args.readme:
            print(f"  Updating README.md...")
            update_readme(example_dir, variants_processed)

if __name__ == "__main__":
    main()