///|
/// tools/inspect — analyse the library's own in-memory component geometry.
///
/// Build a component with the same builders the examples use, then report
/// layer and solid counts, bounding boxes, analytic surface inventories,
/// exact cross-sections, volumes and centroids. No STEP re-import and no
/// Python/OCCT dependency.
///
/// ```bash
/// moon run --target native tools/inspect -- \
///   --standard iso4762 --size M4 --length 20 --detail detailed --json
/// ```
struct LayerInfo {
  name : String
  shape : @cad.Shape
  placement : @common.Placement
}

///|
enum Built {
  Comp(@common.Component)
  Asm(@assemblies.Assembly)
}

///|
fn help_text() -> String {
  [
    "tools/inspect — analytic inspection of the library's in-memory geometry",
    "", "Component families (choose one):", "  --standard NAME   Fastener standard: iso4762, iso4032, iso7089, iso4017,",
    "                    iso4014, iso7380, iso10642, din976", "  --size M4         Metric fastener size (default M4)",
    "  --length MM       Screw/rod length in mm (default 20)", "  --detail LEVEL    simplified | detailed | full (default simplified)",
    "  --threads REP     none | helical | cosmetic (fasteners)", "  --bearing CODE    Bearing designation, e.g. 608, 6204 (default 608)",
    "  --rollers N       Rolling elements; 0 = rings only (default 8)", "  --shielded        Shielded single-solid bearing envelope",
    "  --module MM       Spur gear module (enables the gear family)", "  --teeth N         Tooth count (default 20)",
    "  --bore MM         Bore diameter (default 8)", "  --faceWidth MM    Face width (default 10)",
    "  --shaft           Plain shaft (with --diameter and --shaftLength)", "  --filleted-shaft  Stepped shaft with shoulder fillets (--fillet)",
    "  --keyed-shaft     Shaft with a rectangular keyway (--keywayWidth,", "                    --keywayDepth)",
    "  --diameter MM     Shaft diameter (default 8)", "  --shaftLength MM  Shaft length (default 40)",
    "  --profile SERIES  2020/2040/2060/2080/3030/3060/4040/4080 extrusion", "  --length MM       Extrusion length (default 50)",
    "  --frame WxDxH     T-slot rectangular frame (profile via --profile)", "", "Output:",
    "  --json            Stable JSON (millimetres)", "  --section Z       Repeatable; accepts 5 or z=5. Exact analytic section.",
    "  --volume          Report per-layer and total volume", "  --mesh PATH       Write an OBJ triangle mesh",
    "  --step PATH       Write the generated STEP model (debug cross-check)", "  --self-test       Run built-in assertions and exit non-zero on failure",
    "  --help, -h        Show this help", "", "Limitations: swept/Bezier/fillet/chamfer/difference shapes return typed",
    "NotAnalytic errors for sections and volume; world-z sections are exact", "only for translations and pure Z rotations.",
  ].join("\n")
}

///|
fn get_opts(args : Array[String], name : String) -> Array[String] {
  let pfx = "--" + name
  let pfx_eq = pfx + "="
  let out : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let a = args[i]
    if a == pfx {
      if i + 1 < args.length() {
        out.push(args[i + 1])
        i = i + 2
      } else {
        i = i + 1
      }
    } else if a.has_prefix(pfx_eq) {
      out.push(
        String::unsafe_substring(a, start=pfx_eq.length(), end=a.length()),
      )
      i = i + 1
    } else {
      i = i + 1
    }
  }
  out
}

///|
fn get_opt(args : Array[String], name : String) -> String? {
  let values = get_opts(args, name)
  if values.length() > 0 {
    Some(values[0])
  } else {
    None
  }
}

///|
fn has_flag(args : Array[String], name : String) -> Bool {
  let pfx = "--" + name
  let pfx_eq = pfx + "="
  let mut found = false
  for a in args {
    if a == pfx || a.has_prefix(pfx_eq) {
      found = true
    }
  }
  found
}

///|
fn num(s : String) -> Double {
  @string.parse_double(s.trim().to_owned()) catch {
    _ => abort("error: invalid number: " + s)
  }
}

///|
fn int_num(s : String) -> Int32 {
  @string.parse_int(s.trim().to_owned()) catch {
    _ => abort("error: invalid integer: " + s)
  }
}

///|
fn parse_detail(text : String) -> @common.DetailLevel {
  match text {
    "detailed" | "detail" => @common.DetailLevel::Detailed
    "full" | "fully-modeled" | "fully_modeled" =>
      @common.DetailLevel::FullyModeled
    _ => @common.DetailLevel::Simplified
  }
}

///|
fn parse_threads(text : String?) -> @common.ThreadRepresentation? {
  match text {
    None => None
    Some(value) =>
      match value {
        "none" => Some(@common.ThreadRepresentation::None)
        "helical" | "modeled" => Some(@common.ThreadRepresentation::Helical)
        "cosmetic" => Some(@common.ThreadRepresentation::Cosmetic)
        _ => None
      }
  }
}

///|
fn profile_from_name(name : String) -> @profiles.TSlotProfile? {
  match name {
    "2020" => Some(@profiles.TSlotProfile::generic_2020())
    "2040" => Some(@profiles.TSlotProfile::generic_2040())
    "2060" => Some(@profiles.TSlotProfile::generic_2060())
    "2080" => Some(@profiles.TSlotProfile::generic_2080())
    "3030" => Some(@profiles.TSlotProfile::generic_3030())
    "3060" => Some(@profiles.TSlotProfile::generic_3060())
    "4040" => Some(@profiles.TSlotProfile::generic_4040())
    "4080" => Some(@profiles.TSlotProfile::generic_4080())
    _ => None
  }
}

///|
fn build_fastener(args : Array[String], standard : String) -> Built {
  let size_text = get_opt(args, "size").unwrap_or("M4")
  let size = match @standards.MetricSize::parse(size_text) {
    Some(s) => s
    None => abort("error: unsupported metric size: " + size_text)
  }
  let length = match get_opt(args, "length") {
    Some(s) => num(s)
    None => 20.0
  }
  let detail = parse_detail(get_opt(args, "detail").unwrap_or("simplified"))
  let threads = parse_threads(get_opt(args, "threads"))
  let result : Result[@common.Component, @common.SpecError] = match standard {
    "iso4762" =>
      match threads {
        Some(t) => @fcomponents.iso4762_screw(size, length, detail~, threads=t)
        None => @fcomponents.iso4762_screw(size, length, detail~)
      }
    "iso4032" =>
      match threads {
        Some(t) => @fcomponents.iso4032_nut(size, detail~, threads=t)
        None => @fcomponents.iso4032_nut(size, detail~)
      }
    "iso7089" => @fcomponents.iso7089_washer(size, detail~)
    "iso7380" =>
      match threads {
        Some(t) => @fcomponents.iso7380_screw(size, length, detail~, threads=t)
        None => @fcomponents.iso7380_screw(size, length, detail~)
      }
    "iso10642" =>
      match threads {
        Some(t) => @fcomponents.iso10642_screw(size, length, detail~, threads=t)
        None => @fcomponents.iso10642_screw(size, length, detail~)
      }
    "iso4017" =>
      match threads {
        Some(t) => @fcomponents.iso4017(size, length, detail~, threads=t)
        None => @fcomponents.iso4017(size, length, detail~)
      }
    "iso4014" =>
      match threads {
        Some(t) => @fcomponents.iso4014(size, length, detail~, threads=t)
        None => @fcomponents.iso4014(size, length, detail~)
      }
    "din976" =>
      match threads {
        Some(t) => @fcomponents.din976(size, length, detail~, threads=t)
        None => @fcomponents.din976(size, length, detail~)
      }
    other => abort("error: unsupported standard: " + other)
  }
  match result {
    Ok(c) => Built::Comp(c)
    Err(e) => abort("error: " + e.message())
  }
}

///|
fn build_bearing(args : Array[String], designation : String) -> Built {
  let size = match @motion.bearing_size(designation) {
    Ok(s) => s
    Err(e) => abort("error: " + e.message())
  }
  let detail = parse_detail(get_opt(args, "detail").unwrap_or("simplified"))
  let result = if has_flag(args, "shielded") {
    @motion.shielded_bearing(size, detail~)
  } else {
    let rollers = match get_opt(args, "rollers") {
      Some(s) => int_num(s)
      None => 8
    }
    @motion.bearing(size, roller_count=rollers, detail~)
  }
  match result {
    Ok(c) => Built::Comp(c)
    Err(e) => abort("error: " + e.message())
  }
}

///|
fn build_gear(args : Array[String]) -> Built {
  let module_mm = match get_opt(args, "module") {
    Some(s) => num(s)
    None => 2.0
  }
  let teeth = match get_opt(args, "teeth") {
    Some(s) => int_num(s)
    None => 20
  }
  let bore = match get_opt(args, "bore") {
    Some(s) => num(s)
    None => 8.0
  }
  let face = match get_opt(args, "faceWidth") {
    Some(s) => num(s)
    None => 10.0
  }
  let params = match
    @gears.SpurGearParams::new(
      module_mm~,
      teeth~,
      face_width_mm=face,
      bore_diameter_mm=bore,
    ) {
    Ok(p) => p
    Err(e) => abort("error: " + e.message())
  }
  match @gears.spur_gear(params) {
    Ok(c) => Built::Comp(c)
    Err(e) => abort("error: " + e.message())
  }
}

///|
fn build_motion(args : Array[String]) -> Built {
  let diameter = match get_opt(args, "diameter") {
    Some(s) => num(s)
    None => 8.0
  }
  let length = match get_opt(args, "shaftLength") {
    Some(s) => num(s)
    None => 40.0
  }
  let result = if has_flag(args, "filleted-shaft") {
    let fillet = match get_opt(args, "fillet") {
      Some(s) => num(s)
      None => 2.0
    }
    @motion.filleted_stepped_shaft(
      [(10.0, 20.0), (16.0, 15.0)],
      fillet_radius_mm=fillet,
    )
  } else if has_flag(args, "keyed-shaft") {
    let kw = match get_opt(args, "keywayWidth") {
      Some(s) => num(s)
      None => 6.0
    }
    let kd = match get_opt(args, "keywayDepth") {
      Some(s) => num(s)
      None => 3.5
    }
    @motion.keyed_shaft(diameter, length, kw, kd)
  } else {
    @motion.shaft(diameter, length)
  }
  match result {
    Ok(c) => Built::Comp(c)
    Err(e) => abort("error: " + e.message())
  }
}

///|
fn build_profile(args : Array[String], series : String) -> Built {
  let profile = match profile_from_name(series) {
    Some(p) => p
    None => abort("error: unsupported profile series: " + series)
  }
  let length = match get_opt(args, "length") {
    Some(s) => num(s)
    None => 50.0
  }
  let detail = parse_detail(get_opt(args, "detail").unwrap_or("simplified"))
  match @profiles.extrusion(profile, length, detail~) {
    Ok(c) => Built::Comp(c)
    Err(e) => abort("error: " + e.message())
  }
}

///|
fn build_frame(args : Array[String], spec : String) -> Built {
  let normalized = spec.replace(old="X", new="x")
  let parts = normalized.split("x").collect()
  if parts.length() != 3 {
    abort("error: --frame expects WxDxH (for example 400x300x500)")
  }
  let width = num(parts[0].to_owned())
  let depth = num(parts[1].to_owned())
  let height = num(parts[2].to_owned())
  let series = get_opt(args, "profile").unwrap_or("2020")
  let profile = match profile_from_name(series) {
    Some(p) => p
    None => abort("error: unsupported profile series: " + series)
  }
  let detail = parse_detail(get_opt(args, "detail").unwrap_or("simplified"))
  match @assemblies.extrusion_frame(width, depth, height, profile, detail~) {
    Ok(a) => Built::Asm(a)
    Err(e) => abort("error: " + e.message())
  }
}

///|
fn build(args : Array[String]) -> Built {
  match get_opt(args, "bearing") {
    Some(designation) => return build_bearing(args, designation)
    None => ()
  }
  match get_opt(args, "standard") {
    Some(standard) => return build_fastener(args, standard)
    None => ()
  }
  match get_opt(args, "module") {
    Some(_) => return build_gear(args)
    None => ()
  }
  if has_flag(args, "shaft") ||
    has_flag(args, "filleted-shaft") ||
    has_flag(args, "keyed-shaft") {
    return build_motion(args)
  }
  match get_opt(args, "frame") {
    Some(spec) => return build_frame(args, spec)
    None => ()
  }
  match get_opt(args, "profile") {
    Some(series) => return build_profile(args, series)
    None => ()
  }
  abort(
    "error: no component family selected (use --standard, --bearing, --module, --shaft, --profile, or --frame; see --help)",
  )
}

///|
fn built_name(built : Built) -> String {
  match built {
    Comp(c) => c.name()
    Asm(a) => a.name()
  }
}

///|
fn built_layers(built : Built) -> Array[LayerInfo] {
  match built {
    Comp(c) =>
      c
      .layers()
      .map(fn(l) {
        LayerInfo::{ name: l.name, shape: l.shape, placement: l.placement, }
      })
    Asm(a) =>
      a
      .nodes()
      .map(fn(n) {
        LayerInfo::{
          name: n.name,
          shape: n.shape,
          placement: @common.Placement::at(
            n.tx,
            n.ty,
            n.tz,
            rx=n.rx,
            ry=n.ry,
            rz=n.rz,
          ),
        }
      })
  }
}

///|
fn layer_bbox(
  l : LayerInfo,
) -> (Double, Double, Double, Double, Double, Double) {
  let (rx, ry, rz) = l.placement.to_euler()
  let (tx, ty, tz) = l.placement.trans
  l.shape
  .with_name(l.name)
  .rotate_x(rx)
  .rotate_y(ry)
  .rotate_z(rz)
  .translate(x=tx, y=ty, z=tz)
  .bounding_box()
}

///|
fn bbox_union(
  layers : Array[LayerInfo],
) -> (Double, Double, Double, Double, Double, Double) {
  let mut x0 = 1.0e300
  let mut x1 = -1.0e300
  let mut y0 = 1.0e300
  let mut y1 = -1.0e300
  let mut z0 = 1.0e300
  let mut z1 = -1.0e300
  for l in layers {
    let (a0, a1, b0, b1, c0, c1) = layer_bbox(l)
    if a0 < x0 {
      x0 = a0
    }
    if a1 > x1 {
      x1 = a1
    }
    if b0 < y0 {
      y0 = b0
    }
    if b1 > y1 {
      y1 = b1
    }
    if c0 < z0 {
      z0 = c0
    }
    if c1 > z1 {
      z1 = c1
    }
  }
  if layers.is_empty() {
    (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  } else {
    (x0, x1, y0, y1, z0, z1)
  }
}

///|
fn shape_kind(shape : @cad.Shape) -> String {
  match shape {
    Cuboid(_) => "cuboid"
    Cylinder(_) => "cylinder"
    RevolvedProfile(_) => "revolved-profile"
    ChamferedPrism(_) => "chamfered-prism"
    SocketedSolid(_) => "socketed-solid"
    CalibrationChamferBlock(_) => "calibration-chamfer-block"
    ExtrudedProfile(_) => "extruded-profile"
    ExtrudedArcProfile(_) => "extruded-arc-profile"
    ExtrudedBezierProfile(_) => "extruded-bezier-profile"
    SweptProfile(_) => "swept-profile"
    Fillet(_) => "fillet"
    Chamfer(_) => "chamfer"
    Union(_) => "union"
    Difference(_) => "difference"
  }
}

///|
fn total_inventory(layers : Array[LayerInfo]) -> @cad.SurfaceInventory {
  let mut inv = @cad.SurfaceInventory::empty()
  for l in layers {
    inv = inv.add(l.shape.surface_inventory())
  }
  inv
}

///|
fn jstr(s : String) -> String {
  let a = s.replace(old="\\", new="\\\\")
  a.replace(old="\"", new="\\\"")
}

///|
fn jnum(x : Double) -> String {
  if x != x {
    "null"
  } else if x > 1.0e308 || x < -1.0e308 {
    "null"
  } else {
    x.to_string()
  }
}

///|
fn jbool(b : Bool) -> String {
  if b {
    "true"
  } else {
    "false"
  }
}

///|
fn bbox_json(b : (Double, Double, Double, Double, Double, Double)) -> String {
  let (x0, x1, y0, y1, z0, z1) = b
  "[" +
  jnum(x0) +
  ", " +
  jnum(x1) +
  ", " +
  jnum(y0) +
  ", " +
  jnum(y1) +
  ", " +
  jnum(z0) +
  ", " +
  jnum(z1) +
  "]"
}

///|
fn bbox_text(b : (Double, Double, Double, Double, Double, Double)) -> String {
  bbox_json(b)
}

///|
fn inv_json(inv : @cad.SurfaceInventory) -> String {
  "{\"plane\": " +
  inv.plane.to_string() +
  ", \"cylinder\": " +
  inv.cylinder.to_string() +
  ", \"cone\": " +
  inv.cone.to_string() +
  ", \"sphere\": " +
  inv.sphere.to_string() +
  ", \"torus\": " +
  inv.torus.to_string() +
  ", \"bspline\": " +
  inv.bspline.to_string() +
  ", \"swept\": " +
  inv.swept.to_string() +
  ", \"other\": " +
  inv.other.to_string() +
  "}"
}

///|
fn inv_text(inv : @cad.SurfaceInventory) -> String {
  "plane=" +
  inv.plane.to_string() +
  " cylinder=" +
  inv.cylinder.to_string() +
  " cone=" +
  inv.cone.to_string() +
  " sphere=" +
  inv.sphere.to_string() +
  " torus=" +
  inv.torus.to_string() +
  " bspline=" +
  inv.bspline.to_string() +
  " swept=" +
  inv.swept.to_string() +
  " other=" +
  inv.other.to_string()
}

///|
fn layer_section(
  l : LayerInfo,
  z_world : Double,
) -> Result[@cad.Section, String] {
  let rot = l.placement.rot
  let z_preserved = rot.m02.abs() < 1.0e-7 &&
    rot.m12.abs() < 1.0e-7 &&
    (rot.m22 - 1.0).abs() < 1.0e-7
  if !z_preserved {
    return Err("UnsupportedTransform: " + l.name)
  }
  let z_local = z_world - l.placement.trans.2
  match l.shape.section_at_local(z_local) {
    Ok(s) =>
      Ok(@cad.Section::{
        z_mm: z_world,
        area_mm2: s.area_mm2,
        perimeter_mm: s.perimeter_mm,
        outer_radius_mm: s.outer_radius_mm,
        inner_radius_mm: s.inner_radius_mm,
        rings: s.rings,
      })
    Err(e) => Err(e.message())
  }
}

///|
fn section_json(s : @cad.Section) -> String {
  let rings : Array[String] = []
  for r in s.rings {
    rings.push(
      "{\"inner_radius_mm\": " +
      jnum(r.inner_radius_mm) +
      ", \"outer_radius_mm\": " +
      jnum(r.outer_radius_mm) +
      "}",
    )
  }
  "{\"z_mm\": " +
  jnum(s.z_mm) +
  ", \"area_mm2\": " +
  jnum(s.area_mm2) +
  ", \"perimeter_mm\": " +
  jnum(s.perimeter_mm) +
  ", \"outer_radius_mm\": " +
  jnum(s.outer_radius_mm) +
  ", \"inner_radius_mm\": " +
  jnum(s.inner_radius_mm) +
  ", \"rings\": [" +
  rings.join(", ") +
  "]}"
}

///|
fn parse_sections(args : Array[String]) -> Array[Double] {
  let out : Array[Double] = []
  for raw in get_opts(args, "section") {
    let text = if raw.has_prefix("z=") {
      String::unsafe_substring(raw, start=2, end=raw.length())
    } else if raw.has_prefix("Z=") {
      String::unsafe_substring(raw, start=2, end=raw.length())
    } else {
      raw
    }
    out.push(num(text))
  }
  out
}

///|
fn sections_json(l : LayerInfo, zs : Array[Double]) -> String {
  if zs.is_empty() {
    return ""
  }
  let parts : Array[String] = []
  for z in zs {
    parts.push(
      match layer_section(l, z) {
        Ok(s) => section_json(s)
        Err(msg) =>
          "{\"z_mm\": " + jnum(z) + ", \"error\": \"" + jstr(msg) + "\"}"
      },
    )
  }
  ", \"sections\": [" + parts.join(", ") + "]"
}

///|
fn layer_json(l : LayerInfo, zs : Array[Double]) -> String {
  let vol = match l.shape.analysis_volume() {
    Ok(v) => "\"volume_mm3\": " + jnum(v)
    Err(e) =>
      "\"volume_mm3\": null, \"volume_error\": \"" + jstr(e.message()) + "\""
  }
  "{\"name\": \"" +
  jstr(l.name) +
  "\", \"shape\": \"" +
  shape_kind(l.shape) +
  "\", \"bbox_mm\": " +
  bbox_json(layer_bbox(l)) +
  ", \"surfaces\": " +
  inv_json(l.shape.surface_inventory()) +
  ", " +
  vol +
  sections_json(l, zs) +
  "}"
}

///|
fn total_json(layers : Array[LayerInfo], zs : Array[Double]) -> String {
  let mut volume = 0.0
  let mut complete = true
  let mut any = false
  for l in layers {
    match l.shape.analysis_volume() {
      Ok(v) => {
        volume = volume + v
        any = true
      }
      Err(_) => complete = false
    }
  }
  let vol_json = if any {
    "\"volume_mm3\": " + jnum(volume)
  } else {
    "\"volume_mm3\": null"
  }
  let sections = if zs.is_empty() {
    ""
  } else {
    // Report per layer inside the total block as well, matching the text
    // output's nominal per-layer sections.
    let parts : Array[String] = []
    for l in layers {
      for z in zs {
        parts.push(
          match layer_section(l, z) {
            Ok(s) =>
              "{\"layer\": \"" +
              jstr(l.name) +
              "\", \"z_mm\": " +
              jnum(s.z_mm) +
              ", \"area_mm2\": " +
              jnum(s.area_mm2) +
              ", \"perimeter_mm\": " +
              jnum(s.perimeter_mm) +
              ", \"outer_radius_mm\": " +
              jnum(s.outer_radius_mm) +
              ", \"inner_radius_mm\": " +
              jnum(s.inner_radius_mm) +
              "}"
            Err(msg) =>
              "{\"layer\": \"" +
              jstr(l.name) +
              "\", \"z_mm\": " +
              jnum(z) +
              ", \"error\": \"" +
              jstr(msg) +
              "\"}"
          },
        )
      }
    }
    ", \"sections\": [" + parts.join(", ") + "]"
  }
  "\"bbox_mm\": " +
  bbox_json(bbox_union(layers)) +
  ", " +
  vol_json +
  ", \"volume_complete\": " +
  jbool(complete) +
  ", \"nominal_union\": " +
  jbool(layers.length() > 1) +
  ", \"surfaces\": " +
  inv_json(total_inventory(layers)) +
  sections
}

///|
fn json_output(
  name : String,
  detail : String,
  layers : Array[LayerInfo],
  zs : Array[Double],
) -> String {
  let layer_parts : Array[String] = []
  for l in layers {
    layer_parts.push(layer_json(l, zs))
  }
  "{\"component\": \"" +
  jstr(name) +
  "\", \"detail\": \"" +
  jstr(detail) +
  "\", \"layers\": [" +
  layer_parts.join(", ") +
  "], \"total\": {" +
  total_json(layers, zs) +
  "}}"
}

///|
fn text_output(
  name : String,
  layers : Array[LayerInfo],
  zs : Array[Double],
) -> Unit {
  println("component: " + name)
  println("layers: " + layers.length().to_string())
  println("bbox_mm: " + bbox_text(bbox_union(layers)))
  let mut i = 0
  for l in layers {
    println("layer " + i.to_string() + ": " + l.name)
    println("  shape: " + shape_kind(l.shape))
    println("  bbox_mm: " + bbox_text(layer_bbox(l)))
    println("  surfaces: " + inv_text(l.shape.surface_inventory()))
    match l.shape.analysis_volume() {
      Ok(v) => println("  volume_mm3: " + jnum(v))
      Err(e) => println("  volume_mm3: unavailable (" + e.message() + ")")
    }
    for z in zs {
      match layer_section(l, z) {
        Ok(s) =>
          println(
            "  section z=" +
            jnum(s.z_mm) +
            ": area_mm2=" +
            jnum(s.area_mm2) +
            " perimeter_mm=" +
            jnum(s.perimeter_mm) +
            " outer_radius_mm=" +
            jnum(s.outer_radius_mm) +
            " inner_radius_mm=" +
            jnum(s.inner_radius_mm) +
            " rings=" +
            s.rings.length().to_string(),
          )
        Err(msg) => println("  section z=" + jnum(z) + ": " + msg)
      }
    }
    i = i + 1
  }
  println("total:")
  println("  bbox_mm: " + bbox_text(bbox_union(layers)))
  let mut volume = 0.0
  let mut complete = true
  let mut any = false
  for l in layers {
    match l.shape.analysis_volume() {
      Ok(v) => {
        volume = volume + v
        any = true
      }
      Err(_) => complete = false
    }
  }
  if any {
    println("  volume_mm3: " + jnum(volume))
  }
  println("  volume_complete: " + jbool(complete))
  println("  nominal_union: " + jbool(layers.length() > 1))
  println("  surfaces: " + inv_text(total_inventory(layers)))
}

///|
async fn write_mesh(path : String, layers : Array[LayerInfo]) -> Unit {
  let verts : Array[@cad.Vec3] = []
  let faces : Array[Array[Int32]] = []
  for l in layers {
    match l.shape.analysis_mesh() {
      Ok(result) => {
        let (mv, mf) = result
        let (rx, ry, rz) = l.placement.to_euler()
        let (tx, ty, tz) = l.placement.trans
        let base = verts.length()
        for v in mv {
          let (a, b, c) = @cad.rotate_point(v, rx, ry, rz)
          verts.push((a + tx, b + ty, c + tz))
        }
        for f in mf {
          faces.push(f.map(fn(idx) { idx + base }))
        }
      }
      Err(e) =>
        @cli.eprintln("note: mesh skipped for " + l.name + ": " + e.message())
    }
  }
  if verts.is_empty() {
    abort("error: no layer produced a mesh")
  }
  let lines : Array[String] = []
  for v in verts {
    lines.push("v " + jnum(v.0) + " " + jnum(v.1) + " " + jnum(v.2))
  }
  for f in faces {
    let idxs : Array[String] = []
    for idx in f {
      idxs.push((idx + 1).to_string())
    }
    lines.push("f " + idxs.join(" "))
  }
  @cad.write_text_file(lines.join("\n") + "\n", Some(path))
}

///|
async fn write_step_file(path : String, built : Built) -> Unit {
  match built {
    Comp(c) => c.write_step(Some(path), checked=true)
    Asm(a) => a.write_step(Some(path), checked=true)
  }
}

///|
fn self_test() -> Unit {
  let shape = @cad.Cylinder::new(10.0, 10.0)
  match shape.section_at_local(5.0) {
    Ok(s) =>
      if (s.area_mm2 - 78.53981633974483).abs() > 1.0e-6 {
        abort("self-test failed: cylinder section area " + jnum(s.area_mm2))
      }
    Err(e) => abort("self-test failed: cylinder section: " + e.message())
  }
  match shape.analysis_volume() {
    Ok(v) =>
      if (v - 785.3981633974483).abs() > 1.0e-6 {
        abort("self-test failed: cylinder volume " + jnum(v))
      }
    Err(e) => abort("self-test failed: cylinder volume: " + e.message())
  }
  let inv = shape.surface_inventory()
  if inv.plane != 2 || inv.cylinder != 1 {
    abort("self-test failed: cylinder inventory")
  }
  match @fcomponents.iso4762_screw(@standards.M4, 20.0) {
    Ok(c) =>
      if c.layers().is_empty() {
        abort("self-test failed: fastener has no layers")
      }
    Err(e) => abort("self-test failed: fastener: " + e.message())
  }
  println("self-test: ok")
}

///|
async fn main {
  let args = @env.args().iter().drop(1).collect()
  if has_flag(args, "help") || args.any(fn(a) { a == "-h" }) {
    println(help_text())
    return
  }
  if has_flag(args, "self-test") {
    self_test()
    return
  }
  let built = build(args)
  let name = built_name(built)
  let layers = built_layers(built)
  let zs = parse_sections(args)
  let detail = get_opt(args, "detail").unwrap_or("default")
  if has_flag(args, "json") {
    println(json_output(name, detail, layers, zs))
  } else {
    text_output(name, layers, zs)
  }
  match get_opt(args, "step") {
    Some(path) => write_step_file(path, built)
    None => ()
  }
  match get_opt(args, "mesh") {
    Some(path) => write_mesh(path, layers)
    None => ()
  }
}
