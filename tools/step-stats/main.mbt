///|
/// tools/step-stats — parse-only STEP structure introspection.
///
/// This tool reads a STEP Part 21 file with the library's parser and reports
/// entity and analytic-surface counts plus a point-based bounding box. It does
/// not tessellate, trim, or evaluate booleans, so the point bounding box is not
/// a trimmed-geometry bounding box.
///
/// ```bash
/// moon run tools/step-stats -- file.step --json
/// ```
struct StepStats {
  bytes : Int32
  advanced_face : Int32
  closed_shell : Int32
  open_shell : Int32
  manifold_solid_brep : Int32
  brep_with_voids : Int32
  cartesian_point : Int32
  edge_curve : Int32
  vertex_point : Int32
  circle : Int32
  line : Int32
  plane : Int32
  cylinder : Int32
  cone : Int32
  sphere : Int32
  torus : Int32
  bspline : Int32
  surface_of_revolution : Int32
  surface_of_linear_extrusion : Int32
  bbox : (Double, Double, Double, Double, Double, Double)?
}

///|
fn help_text() -> String {
  [
    "tools/step-stats — parse-only STEP structure inspection", "", "Usage:", "  moon run tools/step-stats -- <file.step> [--json]",
    "  moon run tools/step-stats -- --self-test", "", "Output:",
    "  - file path and size", "  - entity counts (ADVANCED_FACE, CLOSED_SHELL, MANIFOLD_SOLID_BREP,",
    "    CARTESIAN_POINT, EDGE_CURVE, CIRCLE, LINE, VERTEX_POINT, ...)", "  - surface counts (plane, cylinder, cone, sphere, torus, bspline,",
    "    surface_of_revolution, surface_of_linear_extrusion)", "  - solid and shell counts",
    "  - bbox_from_points_mm from every CARTESIAN_POINT", "", "Limitation: this is a structural parser. It does not tessellate, trim,",
    "or compute true sections; bbox_from_points is not a trimmed-geometry", "bounding box. Use scripts/measure_step_*.py for OCCT-authoritative",
    "sections and deviation on imported golden STEP files.",
  ].join("\n")
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
fn bbox_json(b : (Double, Double, Double, Double, Double, Double)?) -> String {
  match b {
    Some(box) => {
      let (x0, x1, y0, y1, z0, z1) = box
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
    None => "null"
  }
}

///|
/// analyze_text parses STEP text and counts structural entities.
fn count_raw_name(counts : Array[Int32], name : String) -> Unit {
  match name {
    "ADVANCED_FACE" => counts[0] = counts[0] + 1
    "CLOSED_SHELL" => counts[1] = counts[1] + 1
    "OPEN_SHELL" => counts[2] = counts[2] + 1
    "MANIFOLD_SOLID_BREP" => counts[3] = counts[3] + 1
    "BREP_WITH_VOIDS" => counts[4] = counts[4] + 1
    "CARTESIAN_POINT" => counts[5] = counts[5] + 1
    "EDGE_CURVE" => counts[6] = counts[6] + 1
    "VERTEX_POINT" => counts[7] = counts[7] + 1
    "CIRCLE" => counts[8] = counts[8] + 1
    "LINE" => counts[9] = counts[9] + 1
    "PLANE" => counts[10] = counts[10] + 1
    "CYLINDRICAL_SURFACE" => counts[11] = counts[11] + 1
    "CONICAL_SURFACE" => counts[12] = counts[12] + 1
    "SPHERICAL_SURFACE" => counts[13] = counts[13] + 1
    "TOROIDAL_SURFACE" => counts[14] = counts[14] + 1
    "B_SPLINE_SURFACE" => counts[15] = counts[15] + 1
    "B_SPLINE_SURFACE_WITH_KNOTS" => counts[15] = counts[15] + 1
    "RATIONAL_B_SPLINE_SURFACE" => counts[15] = counts[15] + 1
    "SURFACE_OF_REVOLUTION" => counts[16] = counts[16] + 1
    "SURFACE_OF_LINEAR_EXTRUSION" => counts[17] = counts[17] + 1
    _ => ()
  }
}

///|
fn analyze_text(text : String, bytes : Int32) -> StepStats {
  let counts : Array[Int32] = Array::make(18, 0)
  let bb : Array[Double] = [
    1.0e300, -1.0e300, 1.0e300, -1.0e300, 1.0e300, -1.0e300,
  ]
  let repo = match @parse.parse_repository_from_string_lenient_result(text) {
    Ok(repo) => repo
    Err(info) => abort("error: " + @parse.format_step_parse_error(info))
  }
  repo.each(fn(entity) {
    match entity {
      @repository.AnyEntity::AdvancedFace(_) => counts[0] = counts[0] + 1
      @repository.AnyEntity::ClosedShell(_) => counts[1] = counts[1] + 1
      @repository.AnyEntity::OpenShell(_) => counts[2] = counts[2] + 1
      @repository.AnyEntity::ManifoldSolidBrep(_) => counts[3] = counts[3] + 1
      @repository.AnyEntity::BrepWithVoids(_) => counts[4] = counts[4] + 1
      @repository.AnyEntity::CartesianPoint(p) => {
        counts[5] = counts[5] + 1
        let c = p.coordinates
        if c.length() >= 3 {
          let (x, y, z) = (c[0], c[1], c[2])
          if x < bb[0] {
            bb[0] = x
          }
          if x > bb[1] {
            bb[1] = x
          }
          if y < bb[2] {
            bb[2] = y
          }
          if y > bb[3] {
            bb[3] = y
          }
          if z < bb[4] {
            bb[4] = z
          }
          if z > bb[5] {
            bb[5] = z
          }
        }
      }
      @repository.AnyEntity::EdgeCurve(_) => counts[6] = counts[6] + 1
      @repository.AnyEntity::VertexPoint(_) => counts[7] = counts[7] + 1
      @repository.AnyEntity::Circle(_) => counts[8] = counts[8] + 1
      @repository.AnyEntity::Line(_) => counts[9] = counts[9] + 1
      @repository.AnyEntity::Plane(_) => counts[10] = counts[10] + 1
      @repository.AnyEntity::CylindricalSurface(_) =>
        counts[11] = counts[11] + 1
      @repository.AnyEntity::ConicalSurface(_) => counts[12] = counts[12] + 1
      @repository.AnyEntity::SphericalSurface(_) => counts[13] = counts[13] + 1
      @repository.AnyEntity::ToroidalSurface(_) => counts[14] = counts[14] + 1
      @repository.AnyEntity::BSplineSurface(_) => counts[15] = counts[15] + 1
      @repository.AnyEntity::BSplineSurfaceWithKnots(_) =>
        counts[15] = counts[15] + 1
      @repository.AnyEntity::RationalBSplineSurface(_) =>
        counts[15] = counts[15] + 1
      @repository.AnyEntity::SurfaceOfRevolution(_) =>
        counts[16] = counts[16] + 1
      @repository.AnyEntity::SurfaceOfLinearExtrusion(_) =>
        counts[17] = counts[17] + 1
      @repository.AnyEntity::RawEntity(r) => count_raw_name(counts, r.name)
      _ => ()
    }
  })
  let bbox = if counts[5] > 0 && bb[0] <= bb[1] {
    Some((bb[0], bb[1], bb[2], bb[3], bb[4], bb[5]))
  } else {
    None
  }
  {
    bytes,
    advanced_face: counts[0],
    closed_shell: counts[1],
    open_shell: counts[2],
    manifold_solid_brep: counts[3],
    brep_with_voids: counts[4],
    cartesian_point: counts[5],
    edge_curve: counts[6],
    vertex_point: counts[7],
    circle: counts[8],
    line: counts[9],
    plane: counts[10],
    cylinder: counts[11],
    cone: counts[12],
    sphere: counts[13],
    torus: counts[14],
    bspline: counts[15],
    surface_of_revolution: counts[16],
    surface_of_linear_extrusion: counts[17],
    bbox,
  }
}

///|
fn stats_json(path : String, stats : StepStats) -> String {
  "{\"path\": \"" +
  jstr(path) +
  "\", \"bytes\": " +
  stats.bytes.to_string() +
  ", \"entities\": {\"ADVANCED_FACE\": " +
  stats.advanced_face.to_string() +
  ", \"CLOSED_SHELL\": " +
  stats.closed_shell.to_string() +
  ", \"OPEN_SHELL\": " +
  stats.open_shell.to_string() +
  ", \"MANIFOLD_SOLID_BREP\": " +
  stats.manifold_solid_brep.to_string() +
  ", \"BREP_WITH_VOIDS\": " +
  stats.brep_with_voids.to_string() +
  ", \"CARTESIAN_POINT\": " +
  stats.cartesian_point.to_string() +
  ", \"EDGE_CURVE\": " +
  stats.edge_curve.to_string() +
  ", \"VERTEX_POINT\": " +
  stats.vertex_point.to_string() +
  ", \"CIRCLE\": " +
  stats.circle.to_string() +
  ", \"LINE\": " +
  stats.line.to_string() +
  "}, \"surfaces\": {\"plane\": " +
  stats.plane.to_string() +
  ", \"cylinder\": " +
  stats.cylinder.to_string() +
  ", \"cone\": " +
  stats.cone.to_string() +
  ", \"sphere\": " +
  stats.sphere.to_string() +
  ", \"torus\": " +
  stats.torus.to_string() +
  ", \"bspline\": " +
  stats.bspline.to_string() +
  ", \"surface_of_revolution\": " +
  stats.surface_of_revolution.to_string() +
  ", \"surface_of_linear_extrusion\": " +
  stats.surface_of_linear_extrusion.to_string() +
  "}, \"solids\": " +
  (stats.manifold_solid_brep + stats.brep_with_voids).to_string() +
  ", \"shells\": " +
  stats.closed_shell.to_string() +
  ", \"bbox_from_points_mm\": " +
  bbox_json(stats.bbox) +
  ", \"note\": \"bbox_from_points is not a trimmed-geometry bounding box\"}"
}

///|
fn stats_text(path : String, stats : StepStats) -> Unit {
  println("path: " + path)
  println("bytes: " + stats.bytes.to_string())
  println("entities:")
  println("  ADVANCED_FACE: " + stats.advanced_face.to_string())
  println("  CLOSED_SHELL: " + stats.closed_shell.to_string())
  println("  OPEN_SHELL: " + stats.open_shell.to_string())
  println("  MANIFOLD_SOLID_BREP: " + stats.manifold_solid_brep.to_string())
  println("  BREP_WITH_VOIDS: " + stats.brep_with_voids.to_string())
  println("  CARTESIAN_POINT: " + stats.cartesian_point.to_string())
  println("  EDGE_CURVE: " + stats.edge_curve.to_string())
  println("  VERTEX_POINT: " + stats.vertex_point.to_string())
  println("  CIRCLE: " + stats.circle.to_string())
  println("  LINE: " + stats.line.to_string())
  println("surfaces:")
  println("  plane: " + stats.plane.to_string())
  println("  cylinder: " + stats.cylinder.to_string())
  println("  cone: " + stats.cone.to_string())
  println("  sphere: " + stats.sphere.to_string())
  println("  torus: " + stats.torus.to_string())
  println("  bspline: " + stats.bspline.to_string())
  println("  surface_of_revolution: " + stats.surface_of_revolution.to_string())
  println(
    "  surface_of_linear_extrusion: " +
    stats.surface_of_linear_extrusion.to_string(),
  )
  println(
    "solids: " + (stats.manifold_solid_brep + stats.brep_with_voids).to_string(),
  )
  println("shells: " + stats.closed_shell.to_string())
  println("bbox_from_points_mm: " + bbox_json(stats.bbox))
  println("note: bbox_from_points is not a trimmed-geometry bounding box")
}

///|
fn self_test() -> Unit {
  let text = "ISO-10303-21;\nDATA;\n#1=CARTESIAN_POINT('',(0.,0.,0.));\n#2=CARTESIAN_POINT('',(10.,20.,30.));\n#3=DIRECTION('',(1.,0.,0.));\n#4=LINE('',#1,#3);\n#5=CIRCLE('',#1,2.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let stats = analyze_text(text, text.length())
  if stats.cartesian_point != 2 ||
    stats.line != 1 ||
    stats.circle != 1 ||
    stats.advanced_face != 0 {
    abort("self-test failed: synthetic entity counts")
  }
  match stats.bbox {
    Some((x0, x1, _y0, y1, _z0, z1)) =>
      if (x0 - 0.0).abs() > 1.0e-9 ||
        (x1 - 10.0).abs() > 1.0e-9 ||
        (y1 - 20.0).abs() > 1.0e-9 ||
        (z1 - 30.0).abs() > 1.0e-9 {
        abort("self-test failed: synthetic point bbox")
      }
    None => abort("self-test failed: synthetic point bbox missing")
  }
  println("self-test: ok")
}

///|
async fn main {
  let args = @env.args().iter().drop(1).collect()
  if args.any(fn(a) { a == "--help" || a == "-h" }) {
    println(help_text())
    return
  }
  if args.any(fn(a) { a == "--self-test" }) {
    self_test()
    return
  }
  let json = args.any(fn(a) { a == "--json" })
  let mut path : String? = None
  for a in args {
    if !a.has_prefix("-") && path is None {
      path = Some(a)
    }
  }
  let file = match path {
    Some(p) => p
    None => abort("error: no STEP file given (see --help)")
  }
  let data = @fs.read_file(file) catch {
    _ => abort("error: cannot read " + file)
  }
  let bytes = data.binary().length()
  let text = data.text() catch {
    _ => abort("error: cannot decode " + file + " as text")
  }
  let stats = analyze_text(text, bytes)
  if json {
    println(stats_json(file, stats))
  } else {
    stats_text(file, stats)
  }
}
