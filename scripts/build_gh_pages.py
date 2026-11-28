#!/usr/bin/env python3
"""Build the static GitHub Pages catalog site for moonbit-step (`_site/`).

Discovers every top-level example (`examples/<NN>-*`) AND every component
example from `./run-example.sh --list`, generates each example's detailed STEP
model via `./run-example.sh`, converts it to an OCCT-tessellated `assembly.glb`
via `./scripts/step_to_glb.py`, renders an isometric PNG thumbnail via
`solidcraft-cli snapshot` (falling back to `./scripts/render_step.py`), and
generates:
  - `_site/index.html` — searchable catalog grid (Examples + Component Library)
  - `_site/examples/<dir>/index.html` — interactive 3D glTF viewer (+ Full Screen)
  - `_site/components/<name>/index.html` — interactive 3D glTF viewer (+ Full Screen)
"""

from __future__ import annotations

import argparse
import html
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


CATALOG_CSS = """\
:root {
  --bg: #f6f8fa;
  --surface: #ffffff;
  --fg: #1f2328;
  --muted: #59636e;
  --border: #d0d7de;
  --accent: #0969da;
  --shadow: 0 2px 10px rgba(31, 35, 40, 0.06);
  --shadow-hover: 0 10px 28px rgba(9, 105, 218, 0.14);
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0d1117;
    --surface: #161b22;
    --fg: #e6edf3;
    --muted: #8b949e;
    --border: #30363d;
    --accent: #58a6ff;
    --shadow: 0 2px 12px rgba(0, 0, 0, 0.35);
    --shadow-hover: 0 12px 30px rgba(88, 166, 255, 0.18);
  }
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--fg);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
  line-height: 1.55;
}
header.hero {
  max-width: 1240px;
  margin: 0 auto;
  padding: 2.5rem 1.5rem 1.25rem;
}
.hero-top {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  justify-content: space-between;
  gap: 1rem;
}
.hero h1 { margin: 0; font-size: 2.1rem; font-weight: 700; letter-spacing: -0.02em; }
.hero-links { display: flex; gap: 0.75rem; align-items: center; }
.pill {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.32rem 0.75rem;
  border: 1px solid var(--border);
  border-radius: 999px;
  background: var(--surface);
  color: var(--fg);
  font-size: 0.85rem;
  font-weight: 550;
  text-decoration: none;
}
.pill:hover { border-color: var(--accent); color: var(--accent); }
.hero p.subtitle { margin: 0.55rem 0 1.2rem; color: var(--muted); max-width: 760px; font-size: 1.02rem; }
.search-bar {
  width: 100%;
  max-width: 440px;
  padding: 0.55rem 0.9rem;
  border: 1px solid var(--border);
  border-radius: 9px;
  background: var(--surface);
  color: var(--fg);
  font: inherit;
  font-size: 0.95rem;
}
.search-bar:focus { outline: 2px solid var(--accent); border-color: var(--accent); }
main { max-width: 1240px; margin: 0 auto; padding: 0.5rem 1.5rem 4rem; }
h2.section-heading {
  margin: 2rem 0 1rem;
  font-size: 1.35rem;
  font-weight: 650;
  padding-bottom: 0.35rem;
  border-bottom: 1px solid var(--border);
}
h2.section-heading:first-of-type { margin-top: 0.75rem; }
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 1.15rem;
}
.card {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--border);
  border-radius: 12px;
  overflow: hidden;
  background: var(--surface);
  color: inherit;
  text-decoration: none;
  box-shadow: var(--shadow);
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
}
.card:hover { transform: translateY(-3px); border-color: var(--accent); box-shadow: var(--shadow-hover); }
.thumb-wrap {
  aspect-ratio: 4 / 3;
  background: radial-gradient(circle at 50% 45%, rgba(100, 145, 210, 0.14), transparent 75%);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  border-bottom: 1px solid var(--border);
}
.thumb-wrap img { width: 100%; height: 100%; object-fit: contain; display: block; }
.thumb-placeholder { color: var(--muted); font-size: 0.88rem; }
.card-body { padding: 0.9rem 1rem 1rem; display: flex; flex-direction: column; gap: 0.3rem; flex: 1; }
.card-tag {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.76rem;
  color: var(--accent);
  font-weight: 600;
}
.card-title { margin: 0; font-size: 1.04rem; font-weight: 650; }
.card-desc {
  margin: 0;
  font-size: 0.86rem;
  color: var(--muted);
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
footer {
  max-width: 1240px;
  margin: 0 auto;
  padding: 1.5rem;
  border-top: 1px solid var(--border);
  color: var(--muted);
  font-size: 0.85rem;
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 0.75rem;
}
footer a { color: var(--accent); text-decoration: none; }
footer a:hover { text-decoration: underline; }
"""

DETAIL_PAGE_CSS = """\
:root {
  --bg: #ffffff;
  --fg: #1f2328;
  --muted: #59636e;
  --border: #d0d7de;
  --accent: #0969da;
  --code-bg: #f6f8fa;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0d1117;
    --fg: #e6edf3;
    --muted: #8b949e;
    --border: #30363d;
    --accent: #58a6ff;
    --code-bg: #161b22;
  }
}
* { box-sizing: border-box; }
body {
  max-width: 1040px;
  margin: 0 auto;
  padding: 1.75rem 1.5rem 3.5rem;
  background: var(--bg);
  color: var(--fg);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
  line-height: 1.6;
}
nav.gh-pages-nav {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 1.25rem;
  padding-bottom: 0.7rem;
  border-bottom: 1px solid var(--border);
  font-size: 0.9rem;
}
nav.gh-pages-nav a { color: var(--accent); text-decoration: none; font-weight: 600; }
nav.gh-pages-nav a:hover { text-decoration: underline; }
h1 { margin: 0 0 0.4rem; font-size: 1.9rem; font-weight: 700; }
p.desc { margin: 0 0 1rem; color: var(--muted); font-size: 1rem; }
pre.cmd {
  margin: 0 0 1.25rem;
  padding: 0.7rem 1rem;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--code-bg);
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.88rem;
  overflow-x: auto;
}
.model-panel {
  position: relative;
  margin: 1rem 0 1.5rem;
  min-height: 540px;
  border: 1px solid var(--border);
  border-radius: 10px;
  overflow: hidden;
  background: radial-gradient(circle at 50% 35%, rgba(100, 145, 210, 0.22), var(--bg) 72%);
}
.model-panel [hidden] { display: none !important; }
.model-panel canvas { display: block; width: 100%; height: 540px; touch-action: none; }
.model-panel:fullscreen, .model-panel:-webkit-full-screen {
  width: 100vw; height: 100vh; margin: 0; border: 0; border-radius: 0;
  background: radial-gradient(circle at 50% 35%, #1e293b, #0b0f17 75%);
}
.model-panel:fullscreen canvas, .model-panel:-webkit-full-screen canvas { width: 100vw; height: 100vh; }
.model-panel .model-fallback { display: block; width: 100%; height: auto; }
.model-hint {
  position: absolute; left: 0.75rem; bottom: 0.65rem;
  padding: 0.25rem 0.6rem; border: 1px solid var(--border); border-radius: 999px;
  background: color-mix(in srgb, var(--bg) 82%, transparent);
  color: var(--muted); font-size: 0.8rem; pointer-events: none;
}
.viewer-toolbar {
  position: absolute; top: 0.75rem; right: 0.75rem;
  display: flex; flex-wrap: wrap; align-items: center; gap: 0.45rem;
  padding: 0.4rem 0.55rem; border: 1px solid var(--border); border-radius: 10px;
  background: color-mix(in srgb, var(--bg) 84%, transparent);
  backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px); z-index: 5;
}
.viewer-btn {
  display: inline-flex; align-items: center; gap: 0.35rem;
  padding: 0.32rem 0.68rem; border: 1px solid var(--border); border-radius: 7px;
  background: color-mix(in srgb, var(--bg) 70%, var(--fg) 6%);
  color: var(--fg); font: inherit; font-size: 0.82rem; font-weight: 550; cursor: pointer;
}
.viewer-btn:hover { border-color: var(--accent); background: color-mix(in srgb, var(--accent) 16%, var(--bg)); }
.viewer-btn.is-active { border-color: var(--accent); background: color-mix(in srgb, var(--accent) 24%, var(--bg)); }
.viewer-part-tooltip {
  position: absolute; right: 0.75rem; bottom: 0.65rem;
  padding: 0.28rem 0.68rem; border: 1px solid var(--accent); border-radius: 999px;
  background: color-mix(in srgb, var(--bg) 88%, transparent);
  color: var(--fg); font-size: 0.8rem; font-weight: 550; pointer-events: none; z-index: 5;
}
.viewer-context-menu {
  position: absolute; min-width: 210px; max-width: 320px; padding: 0.35rem;
  border: 1px solid var(--border); border-radius: 9px;
  background: color-mix(in srgb, var(--bg) 94%, #000 6%);
  box-shadow: 0 10px 28px rgba(0, 0, 0, 0.42); z-index: 20;
}
.viewer-context-header {
  padding: 0.3rem 0.55rem 0.4rem; margin-bottom: 0.25rem;
  border-bottom: 1px solid var(--border); color: var(--muted); font-size: 0.76rem; font-weight: 600;
}
.viewer-context-item {
  display: flex; align-items: center; gap: 0.45rem; width: 100%;
  padding: 0.42rem 0.55rem; border: 0; border-radius: 6px;
  background: transparent; color: var(--fg); font: inherit; font-size: 0.84rem; text-align: left; cursor: pointer;
}
.viewer-context-item:hover { background: color-mix(in srgb, var(--accent) 22%, transparent); }
.viewer-focus-badge {
  position: absolute; left: 0.75rem; top: 0.75rem;
  display: inline-flex; align-items: center; gap: 0.45rem; max-width: 55%;
  padding: 0.32rem 0.6rem 0.32rem 0.75rem; border: 1px solid var(--accent); border-radius: 999px;
  background: color-mix(in srgb, var(--bg) 90%, var(--accent) 10%);
  color: var(--fg); font-size: 0.8rem; font-weight: 600; z-index: 6;
}
.viewer-focus-clear {
  border: 0; border-radius: 999px; padding: 0.1rem 0.45rem;
  background: color-mix(in srgb, var(--accent) 22%, transparent); color: var(--fg); cursor: pointer;
}
.viewer-toast {
  position: absolute; left: 50%; bottom: 0.75rem; transform: translateX(-50%);
  padding: 0.35rem 0.85rem; border: 1px solid var(--accent); border-radius: 999px;
  background: color-mix(in srgb, var(--bg) 92%, transparent);
  color: var(--fg); font-size: 0.82rem; font-weight: 550; pointer-events: none; z-index: 25;
}
"""


def read_module_info(repo_root: Path) -> tuple[str, str]:
    text = (repo_root / "moon.mod").read_text(encoding="utf-8")
    name_m = re.search(r'(?m)^name\s*=\s*"([^"]+)"', text)
    ver_m = re.search(r'(?m)^version\s*=\s*"([^"]+)"', text)
    return (
        name_m.group(1) if name_m else "gmlewis/step",
        ver_m.group(1) if ver_m else "0.0.0",
    )


def find_solidcraft() -> str | None:
    home_bin = Path.home() / "tools" / "bin" / "solidcraft-cli"
    if home_bin.is_file() and os.access(home_bin, os.X_OK):
        return str(home_bin)
    return shutil.which("solidcraft-cli")


def discover_all_examples(repo_root: Path, include_components: bool) -> list[dict[str, str]]:
    """Parse `./run-example.sh --list` to discover every top-level & component example."""
    proc = subprocess.run(
        ["./run-example.sh", "--list"],
        cwd=str(repo_root),
        capture_output=True,
        text=True,
        check=True,
    )
    items: list[dict[str, str]] = []
    section = ""
    for line in proc.stdout.splitlines():
        if line.startswith("Examples ("):
            section = "examples"
            continue
        if line.startswith("Component examples ("):
            section = "components"
            continue
        if not line.startswith("  "):
            continue
        if section == "examples":
            m = re.match(r"^\s+(\d+)\s+(\S+)\s+(.*)$", line)
            if m:
                num, name, desc = m.group(1), m.group(2), m.group(3).strip()
                dir_name = f"{num}-{name}"
                items.append({
                    "kind": "examples",
                    "cli_arg": dir_name,
                    "slug": dir_name,
                    "rel_url": f"examples/{dir_name}/",
                    "title": name.replace("-", " ").replace("_", " ").title(),
                    "desc": desc,
                    "cmd": f"./run-example.sh {num} --view",
                    "src_path": f"examples/{dir_name}",
                })
        elif section == "components" and include_components:
            m = re.match(r"^\s+(\S+)\s+(.*)$", line)
            if m:
                name, desc = m.group(1), m.group(2).strip()
                items.append({
                    "kind": "components",
                    "cli_arg": f"components/{name}",
                    "slug": name,
                    "rel_url": f"components/{name}/",
                    "title": name.replace("_", " ").replace("-", " ").title(),
                    "desc": desc,
                    "cmd": f"./run-example.sh {name} --view",
                    "src_path": f"components",
                })
    return items


def generate_step(repo_root: Path, item: dict[str, str], step_out: Path) -> bool:
    """Run `./run-example.sh` trying `--detail detailed` first, then default flags."""
    for extra in (["--detail", "detailed"], []):
        cmd = ["./run-example.sh", item["cli_arg"], "--headless", "-o", str(step_out), *extra]
        proc = subprocess.run(cmd, cwd=str(repo_root), capture_output=True, text=True)
        if proc.returncode == 0 and step_out.is_file() and step_out.stat().st_size > 100:
            return True
    print(f"warning: failed to generate STEP for {item['cli_arg']}", file=sys.stderr)
    return False


def render_iso_png(repo_root: Path, sc: str | None, step_path: Path, png_path: Path) -> bool:
    if sc:
        proc = subprocess.run(
            [sc, "snapshot", str(step_path.resolve()), str(png_path.resolve()), "--view", "iso", "--width", "800", "--height", "600"],
            capture_output=True,
            text=True,
        )
        if proc.returncode == 0 and png_path.is_file() and png_path.stat().st_size > 100:
            return True
    # Fallback to render_step.py
    proc = subprocess.run(
        [sys.executable, str(repo_root / "scripts" / "render_step.py"), str(step_path), str(png_path)],
        cwd=str(repo_root),
        capture_output=True,
        text=True,
    )
    return proc.returncode == 0 and png_path.is_file() and png_path.stat().st_size > 100


def render_detail_page(
    repo_root: Path,
    item: dict[str, str],
    out_dir: Path,
    repo_url: str,
    has_thumb: bool,
) -> None:
    shutil.copy2(repo_root / "scripts" / "viewer.js", out_dir / "viewer.js")
    fallback_img = (
        f'<img class="model-fallback" src="preview.png" alt="{html.escape(item["title"])}">'
        if has_thumb
        else ""
    )
    doc = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(item["slug"])} — {html.escape(item["title"])}</title>
  <style>{DETAIL_PAGE_CSS}</style>
</head>
<body>
  <nav class="gh-pages-nav">
    <a href="../../">← All Examples</a>
    <a href="{html.escape(repo_url)}/tree/master/{html.escape(item["src_path"])}" target="_blank" rel="noopener">View Source on GitHub ↗</a>
  </nav>
  <h1>{html.escape(item["title"])}</h1>
  <p class="desc">{html.escape(item["desc"])}</p>
  <pre class="cmd">{html.escape(item["cmd"])}</pre>
  <div class="model-panel" id="model-panel">
    {fallback_img}
    <canvas hidden aria-label="Interactive 3D model view"></canvas>
    <div class="model-hint" hidden></div>
  </div>
  <script type="importmap">{{"imports":{{"three":"https://cdn.jsdelivr.net/npm/three@0.170.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/"}}}}</script>
  <script type="module" src="viewer.js"></script>
</body>
</html>
"""
    (out_dir / "index.html").write_text(doc, encoding="utf-8")


def write_catalog_index(
    site_dir: Path,
    module_name: str,
    version: str,
    repo_url: str,
    cards: list[dict[str, str]],
) -> None:
    def render_cards(subset: list[dict[str, str]]) -> str:
        out: list[str] = []
        for c in subset:
            thumb = (
                f'<img src="{html.escape(c["thumb"])}" alt="{html.escape(c["title"])}" loading="lazy">'
                if c["thumb"]
                else '<span class="thumb-placeholder">Interactive 3D Model</span>'
            )
            search_text = html.escape(f'{c["slug"]} {c["title"]} {c["desc"]}'.lower())
            out.append(
                f'<a class="card" href="{html.escape(c["href"])}" data-search="{search_text}">\n'
                f'  <div class="thumb-wrap">{thumb}</div>\n'
                f'  <div class="card-body">\n'
                f'    <div class="card-tag">{html.escape(c["tag"])}</div>\n'
                f'    <h3 class="card-title">{html.escape(c["title"])}</h3>\n'
                f'    <p class="card-desc">{html.escape(c["desc"])}</p>\n'
                f'  </div>\n'
                f'</a>'
            )
        return "\n".join(out)

    ex_cards = [c for c in cards if c["kind"] == "examples"]
    comp_cards = [c for c in cards if c["kind"] == "components"]
    sections = []
    if ex_cards:
        sections.append(f'<h2 class="section-heading">Examples ({len(ex_cards)})</h2>\n<div class="grid">{render_cards(ex_cards)}</div>')
    if comp_cards:
        sections.append(f'<h2 class="section-heading">Component Library ({len(comp_cards)})</h2>\n<div class="grid">{render_cards(comp_cards)}</div>')

    doc = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(module_name)} — Interactive STEP Catalog</title>
  <style>{CATALOG_CSS}</style>
</head>
<body>
  <header class="hero">
    <div class="hero-top">
      <h1>{html.escape(module_name)}</h1>
      <div class="hero-links">
        <span class="pill">v{html.escape(version)}</span>
        <a class="pill" href="{html.escape(repo_url)}" target="_blank" rel="noopener">GitHub Repo ↗</a>
      </div>
    </div>
    <p class="subtitle">
      Interactive 3D STEP geometry catalog generated from MoonBit source code.
      Click any card below to inspect the detailed 3D model in full screen.
    </p>
    <input type="search" id="filter" class="search-bar" placeholder="Filter {len(cards)} examples & components…" aria-label="Filter examples">
  </header>
  <main id="catalog-main">
    {"".join(sections)}
  </main>
  <footer>
    <span>Generated locally by <code>./publish-gh-pages.sh</code> ({len(cards)} models)</span>
    <a href="{html.escape(repo_url)}" target="_blank" rel="noopener">{html.escape(repo_url)}</a>
  </footer>
  <script>
    const input = document.getElementById("filter");
    const cards = Array.from(document.querySelectorAll("#catalog-main .card"));
    input.addEventListener("input", () => {{
      const q = input.value.trim().toLowerCase();
      for (const c of cards) {{
        const hay = c.getAttribute("data-search") || "";
        c.style.display = !q || hay.includes(q) ? "" : "none";
      }}
    }});
  </script>
</body>
</html>
"""
    (site_dir / "index.html").write_text(doc, encoding="utf-8")
    (site_dir / ".nojekyll").write_text("", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build GitHub Pages catalog for moonbit-step.")
    parser.add_argument("--out", default="_site", help="Output directory (default: _site)")
    parser.add_argument("--only", default="", help="Comma-separated example/component names or numbers (e.g. 38,bearing)")
    parser.add_argument("--skip-components", action="store_true", help="Only build top-level examples/")
    parser.add_argument("--repo-url", default="https://github.com/gmlewis/moonbit-step", help="GitHub repository URL")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    site_dir = Path(args.out)
    if not site_dir.is_absolute():
        site_dir = repo_root / site_dir

    only_tokens = {t.strip().lower() for t in args.only.split(",") if t.strip()}
    items = discover_all_examples(repo_root, include_components=not args.skip_components)
    if only_tokens:
        items = [
            it for it in items
            if it["slug"].lower() in only_tokens
            or it["cli_arg"].lower() in only_tokens
            or re.split(r"[-_]", it["slug"], maxsplit=1)[0].lower() in only_tokens
        ]
        if not items:
            print(f"error: no examples matched --only {args.only}", file=sys.stderr)
            return 2

    if site_dir.exists() and not only_tokens:
        shutil.rmtree(site_dir)
    site_dir.mkdir(parents=True, exist_ok=True)

    sc = find_solidcraft()
    module_name, version = read_module_info(repo_root)
    cards: list[dict[str, str]] = []

    for it in items:
        print(f"==> Building {it['rel_url']} ...")
        page_dir = site_dir / it["kind"] / it["slug"]
        page_dir.mkdir(parents=True, exist_ok=True)
        tmp_step = Path("/tmp") / f"gh-pages-step-{it['slug']}.step"
        try:
            if not generate_step(repo_root, it, tmp_step):
                continue
            glb_path = page_dir / "assembly.glb"
            proc = subprocess.run(
                [sys.executable, str(repo_root / "scripts" / "step_to_glb.py"), str(tmp_step), "-o", str(glb_path)],
                cwd=str(repo_root),
                capture_output=True,
                text=True,
            )
            if proc.returncode != 0 or not glb_path.is_file():
                print(f"warning: step_to_glb.py failed for {it['slug']}: {proc.stderr.strip()}", file=sys.stderr)
                continue
            png_path = page_dir / "preview.png"
            has_thumb = render_iso_png(repo_root, sc, tmp_step, png_path)
            render_detail_page(repo_root, it, page_dir, args.repo_url, has_thumb)
            cards.append({
                "kind": it["kind"],
                "slug": it["slug"],
                "tag": f"{it['kind']}/{it['slug']}",
                "title": it["title"],
                "desc": it["desc"],
                "href": it["rel_url"],
                "thumb": f"{it['rel_url']}preview.png" if has_thumb else "",
            })
        finally:
            if tmp_step.exists():
                tmp_step.unlink()

    write_catalog_index(site_dir, module_name, version, args.repo_url, cards)
    print(f"==> Built {len(cards)} model page(s) into {site_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
