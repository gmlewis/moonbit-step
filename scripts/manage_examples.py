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
    "03": [["--name", "gmlewis"], ["--name", "MoonBit", "--embossDepth", "2", "--length", "60"]],
    "04": [["--id", "5", "--od", "15", "--thickness", "2"], ["--id", "10", "--od", "12", "--thickness", "0.5", "--segments", "32"]],
    "05": [["--rows", "1", "--cols", "1", "--height", "20"], ["--rows", "2", "--cols", "1", "--text", "Gemini"]],
    "06": [["--count", "1"], ["--count", "3", "--height", "10", "--clickHeight", "1"]],
    "07": [["--diameter", "5", "--text", "USB"], ["--diameter", "10", "--text", "POWER", "--length", "30"]],
    "08": [["--stepCount", "3"], ["--stepCount", "5", "--interference", "0.2", "--interferenceStep", "0.2"]],
    "09": [["--baseWidth", "60", "--baseLength", "80"], ["--dovetailAngle", "20", "--dovetailHeight", "10"], ["--clearance", "0.5"]]
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

        new_section += f"\n### Variant {i}\n\n"
        new_section += f"Command line: `./run-example.sh {example_dir.name[:2]} {arg_str}`\n\n"

        if preview:
            new_section += f"![]({preview})\n"
        else:
            new_section += "_[Render Failed]_\n"

    readme_path.write_text(content + new_section + "\n")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("target", help="Example number or 'all'")
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--readme", action="store_true")
    args = parser.parse_args()

    occt_bin = find_occt()
    inkscape_bin = shutil.which("inkscape")

    if args.render and not inkscape_bin:
        print("Error: 'inkscape' not found in PATH. Required for rendering.")
        sys.exit(1)

    targets = sorted(SUITE.keys()) if args.target == "all" else [args.target]

    for num in targets:
        # Handle non-padded input (e.g., "3" -> "03")
        padded_num = num.zfill(2)
        if padded_num not in SUITE:
            print(f"Example {num} (padded: {padded_num}) not found in SUITE.")
            continue

        example_dir = find_example_dir(padded_num)
        if not example_dir:
            print(f"Example directory for {padded_num} not found.")
            continue

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
            step_file = Path(f"/tmp/example-{padded_num}-{i}.step")

            if not generate_step(padded_num, config, step_file): continue

            if args.validate:
                if validate_step(occt_bin, step_file):
                    print("    Topology: OK")
                else:
                    print("    Topology: FAILED")
                    continue

            preview = None
            if args.render:
                preview = render_variant(occt_bin, inkscape_bin, step_file, example_dir, i)
                if preview:
                    print(f"    Render: SUCCESS ({preview})")
                else:
                    print(f"    Render: FAILED")

            variants_processed.append({"config": config, "preview": preview})

        if args.readme:
            print(f"  Updating README.md...")
            update_readme(example_dir, variants_processed)

if __name__ == "__main__":
    main()