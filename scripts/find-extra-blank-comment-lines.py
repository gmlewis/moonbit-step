#!/usr/bin/env python3
"""
Script to find and remove extra blank comment lines in *.mbt files.

Matches the 3-line pattern:
- Line N: completely blank (only whitespace or empty)
- Line N+1: one or more whitespace followed by "//" followed by newline
- Line N+2: one or more whitespace followed by "//" then content

Removes Line N+1 when this pattern is found.
Skips 'target' and '.mooncakes' directories.
"""

import re
import sys
from pathlib import Path


def process_file(filepath):
    """Process a single .mbt file to remove the specified pattern."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading {filepath}: {e}", file=sys.stderr)
        return False

    new_lines = []
    i = 0
    changed = False

    while i < len(lines):
        if i + 2 < len(lines):
            line1 = lines[i]
            line2 = lines[i + 1]
            line3 = lines[i + 2]

            # Check the pattern
            if (re.match(r'^\s*$', line1) and
                re.match(r'^\s+//\s*$', line2) and
                re.match(r'^\s+//.*$', line3)):
                # Remove line2 (the extra blank comment line)
                new_lines.append(line1)
                new_lines.append(line3)
                i += 3
                changed = True
                continue

        new_lines.append(lines[i])
        i += 1

    if changed:
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            print(f"Updated {filepath}")
            return True
        except Exception as e:
            print(f"Error writing {filepath}: {e}", file=sys.stderr)
            return False

    return False


def main():
    """Main function to find and process all .mbt files."""
    root_dir = Path('.')
    mbt_files = []

    # Find all .mbt files, excluding target and .mooncakes directories
    for path in root_dir.rglob('*.mbt'):
        if 'target' not in path.parts and '.mooncakes' not in path.parts:
            mbt_files.append(path)

    print(f"Found {len(mbt_files)} .mbt files to process.")

    updated_count = 0
    for filepath in mbt_files:
        if process_file(filepath):
            updated_count += 1

    print(f"Processed {len(mbt_files)} files, updated {updated_count} files.")


if __name__ == '__main__':
    main()