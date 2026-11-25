///|
/// Native SolidCraft JSON command script emitter (`Design::to_solidcraft_script`
/// and `Design::write_solidcraft_script`).
///
/// Emits a list of SolidCraft commands (`file.new`, `solid.box`,
/// `solid.cylinder`, `file.insert_step`, `solid.move`, `solid.combine`,
/// `appearance.assign`) so `moon run` finishes in < 0.5 s and either:
/// - streams live into the open SolidCraft GUI via `scripts/run_solidcraft_live.py`
///   (sub-second popup, watch bodies & booleans materialize in real time, full
///   editable feature tree), OR
/// - runs headless via `solidcraft-cli run <script.json>` for fast `.step` /
///   `.3mf` / `.stl` export.

///|
/// A compiled SolidCraft command script plus any leaf STEP files that complex
/// shapes (`SweptProfile`, `RevolvedProfile`, `ExtrudedArcProfile`, etc.)
/// require `file.insert_step` to load.
pub(all) struct SolidCraftScript {
  script_json : String
  leaf_files : Array[(String, String)]
}

///|
fn sc_rgb_hex(c : Rgb) -> String {
  let (r, g, b) = c.channels()
  let clamp = fn(v : Double) -> Int32 {
    let n = (v * 255.0 + 0.5).to_int()
    if n < 0 {
      0
    } else if n > 255 {
      255
    } else {
      n
    }
  }
  let hex2 = fn(n : Int32) -> String {
    let digits = "0123456789abcdef"
    let hi = (n / 16) & 15
    let lo = n & 15
    digits[hi:hi + 1].to_owned() + digits[lo:lo + 1].to_owned()
  }
  "#" + hex2(clamp(r)) + hex2(clamp(g)) + hex2(clamp(b))
}

///|
fn sc_json_str(s : String) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  for ch in s {
    match ch {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(ch)
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
fn sc_num(v : Double) -> String {
  let clean = if v.abs() < 1.0e-12 { 0.0 } else { v }
  clean.to_string()
}

///|
fn sc_transform_is_identity(t : Transform) -> Bool {
  let r = t.rot
  let eps = 1.0e-9
  (r.m00 - 1.0).abs() < eps &&
  r.m01.abs() < eps &&
  r.m02.abs() < eps &&
  r.m10.abs() < eps &&
  (r.m11 - 1.0).abs() < eps &&
  r.m12.abs() < eps &&
  r.m20.abs() < eps &&
  r.m21.abs() < eps &&
  (r.m22 - 1.0).abs() < eps &&
  t.trans.0.abs() < eps &&
  t.trans.1.abs() < eps &&
  t.trans.2.abs() < eps
}

///|
fn sc_transform_is_pure_translation(t : Transform) -> Bool {
  let r = t.rot
  let eps = 1.0e-9
  (r.m00 - 1.0).abs() < eps &&
  r.m01.abs() < eps &&
  r.m02.abs() < eps &&
  r.m10.abs() < eps &&
  (r.m11 - 1.0).abs() < eps &&
  r.m12.abs() < eps &&
  r.m20.abs() < eps &&
  r.m21.abs() < eps &&
  (r.m22 - 1.0).abs() < eps
}

///|
fn sc_matrix3x4_json(t : Transform) -> String {
  let r = t.rot
  let (tx, ty, tz) = t.trans
  "[" +
  sc_num(r.m00) +
  "," +
  sc_num(r.m01) +
  "," +
  sc_num(r.m02) +
  "," +
  sc_num(tx) +
  "," +
  sc_num(r.m10) +
  "," +
  sc_num(r.m11) +
  "," +
  sc_num(r.m12) +
  "," +
  sc_num(ty) +
  "," +
  sc_num(r.m20) +
  "," +
  sc_num(r.m21) +
  "," +
  sc_num(r.m22) +
  "," +
  sc_num(tz) +
  "]"
}

///|
priv struct ScEmitter {
  leaves_dir : String
  commands : Array[String]
  leaf_files : Array[(String, String)]
  mut next_id : Int32
}

///|
fn sc_sanitize_ident(s : String) -> String {
  let buf = StringBuilder()
  for ch in s {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '_' ||
      ch == '-' {
      buf.write_char(ch)
    } else {
      buf.write_char('_')
    }
  }
  let res = buf.to_string()
  if res.is_empty() {
    "body"
  } else {
    res
  }
}

///|
fn ScEmitter::fresh_name(self : ScEmitter, hint : String) -> String {
  let id = self.next_id
  self.next_id = id + 1
  let clean = sc_sanitize_ident(hint)
  "\{clean}_\{id}"
}

///|
fn ScEmitter::emit_node(
  self : ScEmitter,
  node : SceneNode,
  parent : Transform?,
  top_level : Bool,
) -> String? {
  let xf = node_transform(node, parent)
  match node.shape {
    Cuboid(c) => {
      let bname = if top_level && !node.name.is_empty() {
        node.name
      } else {
        self.fresh_name(node.name)
      }
      if sc_transform_is_pure_translation(xf) {
        let (tx, ty, tz) = xf.trans
        self.commands.push(
          "  {\"command\": \"solid.box\", \"params\": {\"length\": " +
          sc_num(c.sx) +
          ", \"width\": " +
          sc_num(c.sy) +
          ", \"height\": " +
          sc_num(c.sz) +
          ", \"corner\": [" +
          sc_num(tx) +
          ", " +
          sc_num(ty) +
          ", " +
          sc_num(tz) +
          "], \"body_name\": " +
          sc_json_str(bname) +
          "}}",
        )
      } else {
        self.commands.push(
          "  {\"command\": \"solid.box\", \"params\": {\"length\": " +
          sc_num(c.sx) +
          ", \"width\": " +
          sc_num(c.sy) +
          ", \"height\": " +
          sc_num(c.sz) +
          ", \"corner\": [0, 0, 0], \"body_name\": " +
          sc_json_str(bname) +
          "}}",
        )
        self.commands.push(
          "  {\"command\": \"solid.move\", \"params\": {\"bodies\": [" +
          sc_json_str(bname) +
          "], \"matrix\": " +
          sc_matrix3x4_json(xf) +
          "}}",
        )
      }
      if top_level {
        self.commands.push(
          "  {\"command\": \"appearance.assign\", \"params\": {\"bodies\": [" +
          sc_json_str(bname) +
          "], \"color\": " +
          sc_json_str(sc_rgb_hex(node.color)) +
          "}}",
        )
      }
      Some(bname)
    }
    Cylinder(c) => {
      let bname = if top_level && !node.name.is_empty() {
        node.name
      } else {
        self.fresh_name(node.name)
      }
      if sc_transform_is_pure_translation(xf) {
        let (tx, ty, tz) = xf.trans
        self.commands.push(
          "  {\"command\": \"solid.cylinder\", \"params\": {\"diameter\": " +
          sc_num(c.diameter) +
          ", \"height\": " +
          sc_num(c.height) +
          ", \"base\": [" +
          sc_num(tx) +
          ", " +
          sc_num(ty) +
          ", " +
          sc_num(tz) +
          "], \"body_name\": " +
          sc_json_str(bname) +
          "}}",
        )
      } else {
        self.commands.push(
          "  {\"command\": \"solid.cylinder\", \"params\": {\"diameter\": " +
          sc_num(c.diameter) +
          ", \"height\": " +
          sc_num(c.height) +
          ", \"base\": [0, 0, 0], \"body_name\": " +
          sc_json_str(bname) +
          "}}",
        )
        self.commands.push(
          "  {\"command\": \"solid.move\", \"params\": {\"bodies\": [" +
          sc_json_str(bname) +
          "], \"matrix\": " +
          sc_matrix3x4_json(xf) +
          "}}",
        )
      }
      if top_level {
        self.commands.push(
          "  {\"command\": \"appearance.assign\", \"params\": {\"bodies\": [" +
          sc_json_str(bname) +
          "], \"color\": " +
          sc_json_str(sc_rgb_hex(node.color)) +
          "}}",
        )
      }
      Some(bname)
    }
    Union(u) => {
      if u.nodes.is_empty() {
        return None
      }
      let emitted : Array[String] = []
      for child in u.nodes {
        match self.emit_node(child, Some(xf), false) {
          Some(b) => emitted.push(b)
          None => ()
        }
      }
      if emitted.is_empty() {
        return None
      }
      let target = emitted[0]
      if emitted.length() > 1 {
        let tools_json = StringBuilder()
        tools_json.write_char('[')
        for i in 1..<emitted.length() {
          if i > 1 {
            tools_json.write_string(", ")
          }
          tools_json.write_string(sc_json_str(emitted[i]))
        }
        tools_json.write_char(']')
        self.commands.push(
          "  {\"command\": \"solid.combine\", \"params\": {\"target\": " +
          sc_json_str(target) +
          ", \"tools\": " +
          tools_json.to_string() +
          ", \"operation\": \"join\"}}",
        )
      }
      if top_level {
        self.commands.push(
          "  {\"command\": \"appearance.assign\", \"params\": {\"bodies\": [" +
          sc_json_str(target) +
          "], \"color\": " +
          sc_json_str(sc_rgb_hex(node.color)) +
          "}}",
        )
      }
      Some(target)
    }
    Difference(d) => {
      let target = match self.emit_node(d.base, Some(xf), false) {
        Some(b) => b
        None => return None
      }
      let tools : Array[String] = []
      for cutter in d.cutters {
        match self.emit_node(cutter, Some(xf), false) {
          Some(b) => tools.push(b)
          None => ()
        }
      }
      if !tools.is_empty() {
        let tools_json = StringBuilder()
        tools_json.write_char('[')
        for i in 0..<tools.length() {
          if i > 0 {
            tools_json.write_string(", ")
          }
          tools_json.write_string(sc_json_str(tools[i]))
        }
        tools_json.write_char(']')
        self.commands.push(
          "  {\"command\": \"solid.combine\", \"params\": {\"target\": " +
          sc_json_str(target) +
          ", \"tools\": " +
          tools_json.to_string() +
          ", \"operation\": \"cut\"}}",
        )
      }
      if top_level {
        self.commands.push(
          "  {\"command\": \"appearance.assign\", \"params\": {\"bodies\": [" +
          sc_json_str(target) +
          "], \"color\": " +
          sc_json_str(sc_rgb_hex(node.color)) +
          "}}",
        )
      }
      Some(target)
    }
    _ => {
      // Complex analytic / swept / revolved / imported leaf: emit one compact
      // standalone STEP file and load via `file.insert_step`.
      let bname = self.fresh_name(node.name)
      let leaf_rel = "\{bname}.step"
      let leaf_path = if self.leaves_dir.has_suffix("/") {
        self.leaves_dir + leaf_rel
      } else {
        self.leaves_dir + "/" + leaf_rel
      }
      let raw_leaf : SceneNode = {
        shape: node.shape,
        name: bname,
        color: node.color,
        tx: 0.0,
        ty: 0.0,
        tz: 0.0,
        rx: 0.0,
        ry: 0.0,
        rz: 0.0,
      }
      let step_text = Design::new(name=bname).add(raw_leaf).to_step_file()
      self.leaf_files.push((leaf_path, step_text))
      if sc_transform_is_identity(xf) {
        self.commands.push(
          "  {\"command\": \"file.insert_step\", \"params\": {\"path\": " +
          sc_json_str(leaf_path) +
          ", \"flatten\": true, \"name\": " +
          sc_json_str(bname) +
          "}}",
        )
      } else {
        self.commands.push(
          "  {\"command\": \"file.insert_step\", \"params\": {\"path\": " +
          sc_json_str(leaf_path) +
          ", \"flatten\": true, \"name\": " +
          sc_json_str(bname) +
          ", \"matrix\": " +
          sc_matrix3x4_json(xf) +
          "}}",
        )
      }
      if top_level {
        self.commands.push(
          "  {\"command\": \"appearance.assign\", \"params\": {\"bodies\": [" +
          sc_json_str(bname) +
          "], \"color\": " +
          sc_json_str(sc_rgb_hex(node.color)) +
          "}}",
        )
      }
      Some(bname)
    }
  }
}

///|
/// Compiles this `Design` into a native SolidCraft JSON command script plus
/// any complex leaf STEP files (stored under `leaves_dir`).
///
/// `Cuboid` and `Cylinder` emit direct `solid.box` / `solid.cylinder` commands
/// (zero leaf STEP files); `Union` and `Difference` emit `solid.combine`;
/// complex shapes (`SweptProfile`, `RevolvedProfile`, `ExtrudedArcProfile`)
/// emit compact leaf STEP files loaded via `file.insert_step`.
pub fn Design::to_solidcraft_script(
  self : Design,
  leaves_dir~ : String = "/tmp/sc-leaves",
  include_file_new~ : Bool = true,
) -> SolidCraftScript {
  let em : ScEmitter = { leaves_dir, commands: [], leaf_files: [], next_id: 1, }
  if include_file_new {
    let title = if self.name.is_empty() { "design" } else { self.name }
    em.commands.push(
      "  {\"command\": \"file.new\", \"params\": {\"name\": " +
      sc_json_str(title) +
      "}}",
    )
  }
  for node in self.nodes {
    let _ = em.emit_node(node, None, true)
  }
  let buf = StringBuilder()
  buf.write_string("[\n")
  for i in 0..<em.commands.length() {
    buf.write_string(em.commands[i])
    if i + 1 < em.commands.length() {
      buf.write_char(',')
    }
    buf.write_char('\n')
  }
  buf.write_string("]\n")
  { script_json: buf.to_string(), leaf_files: em.leaf_files, }
}

///|
/// Writes the SolidCraft JSON command script to `script_path` and any required
/// leaf STEP files into `leaves_dir` (default: `<script_path>.leaves`).
pub async fn Design::write_solidcraft_script(
  self : Design,
  script_path : String,
  leaves_dir? : String,
  include_file_new~ : Bool = true,
) -> Unit {
  let ldir = leaves_dir.unwrap_or(script_path + ".leaves")
  let built = self.to_solidcraft_script(leaves_dir=ldir, include_file_new~)
  if !built.leaf_files.is_empty() {
    if !@fs.exists(ldir) {
      @fs.mkdir(ldir, permission=0o755, recursive=true)
    }
    for pair in built.leaf_files {
      write_text_file(pair.1, Some(pair.0))
    }
  }
  write_text_file(built.script_json, Some(script_path))
}
