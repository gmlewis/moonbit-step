///|
/// Number of line segments used to approximate each cubic Bezier span when
/// flattening an `ExtrudedBezierProfile` for STEP output.
///
/// STEP cannot express the glyph outlines directly, so the curves are sampled
/// into polylines before the profile is extruded. Eight segments per span keeps
/// the resulting files comparable in size to the `segments=8` polyline path.
let bezier_segments_per_span : Int32 = 8

///|
/// cubic_bezier_point evaluates the cubic Bezier defined by the four control
/// points at parameter `t`.
fn cubic_bezier_point(
  p0 : Vec2,
  c1 : Vec2,
  c2 : Vec2,
  p3 : Vec2,
  t : Double,
) -> Vec2 {
  let u = 1.0 - t
  let uu = u * u
  let tt = t * t
  let uuu = uu * u
  let ttt = tt * t
  let ut3 = 3.0 * uu * t
  let tu3 = 3.0 * u * tt
  (
    uuu * p0.0 + ut3 * c1.0 + tu3 * c2.0 + ttt * p3.0,
    uuu * p0.1 + ut3 * c1.1 + tu3 * c2.1 + ttt * p3.1,
  )
}

///|
/// flatten_bezier_path samples a `BezierPath` into a polyline.
///
/// Handles are stored as absolute positions, so the cubic span from anchor `i`
/// to anchor `i+1` uses `a[i].position`, `a[i].handle_out`,
/// `a[i+1].handle_in`, and `a[i+1].position`. Straight spans (zero-length
/// offsets) contribute only their start point, which avoids bloating glyphs
/// whose stems are simple lines. Closed paths include the wrap-around span.
fn flatten_bezier_path(path : BezierPath) -> Array[Vec2] {
  let anchors = path.anchors
  let n = anchors.length()
  if n < 2 {
    return []
  }
  let points : Array[Vec2] = []
  let span_count = if path.closed { n } else { n - 1 }
  for i in 0..<span_count {
    let a0 = anchors[i]
    let a1 = anchors[(i + 1) % n]
    let p0 = a0.position
    let p3 = a1.position
    let c1 = a0.handle_out
    let c2 = a1.handle_in
    let straight = c1 == p0 && c2 == p3
    if straight {
      points.push(p0)
    } else {
      for j in 0..<bezier_segments_per_span {
        let t = Double::from_int(j) / Double::from_int(bezier_segments_per_span)
        points.push(cubic_bezier_point(p0, c1, c2, p3, t))
      }
    }
  }
  if !path.closed {
    points.push(anchors[n - 1].position)
  }
  dedupe_bezier_points(points)
}

///|
/// dedupe_bezier_points drops consecutive duplicate points and the duplicated
/// closing point of a loop. Extruding zero-length edges makes OCCT unhappy.
fn dedupe_bezier_points(points : Array[Vec2]) -> Array[Vec2] {
  let eps_sq = 1.0e-18
  let result : Array[Vec2] = []
  for pt in points {
    let duplicate = match result.last() {
      Some(prev) => {
        let dx = pt.0 - prev.0
        let dy = pt.1 - prev.1
        dx * dx + dy * dy <= eps_sq
      }
      None => false
    }
    if !duplicate {
      result.push(pt)
    }
  }
  if result.length() > 1 {
    let first = result[0]
    let last = result[result.length() - 1]
    let dx = first.0 - last.0
    let dy = first.1 - last.1
    if dx * dx + dy * dy <= eps_sq {
      let _ = result.pop()
    }
  }
  result
}

///|
/// bezier_path_groups splits `BezierPath`s into (outer, holes) groups while
/// keeping the original curves.
///
/// Disconnected glyph components (for example the dot of an "i", or the pieces
/// of a "%") become separate groups so each can be emitted as its own closed
/// solid. `path.clear == true` marks a hole (see `BezierPath.clear`), and a
/// hole is attached to every outer loop that contains it. Degenerate paths with
/// fewer than three flattened points are skipped.
fn bezier_path_groups(paths : Array[BezierPath]) -> Array[Array[BezierPath]] {
  let outers : Array[(BezierPath, Array[Vec2])] = []
  let holes : Array[(BezierPath, Array[Vec2])] = []
  for path in paths {
    let flat = flatten_bezier_path(path)
    if flat.length() < 3 {
      continue
    }
    if path.clear {
      holes.push((path, flat))
    } else {
      outers.push((path, flat))
    }
  }
  let groups : Array[Array[BezierPath]] = []
  for outer_pair in outers {
    let outer = outer_pair.0
    let outer_poly = outer_pair.1
    let group : Array[BezierPath] = [outer]
    for hole_pair in holes {
      let hole = hole_pair.0
      let hole_poly = hole_pair.1
      if hole_poly.length() > 0 && is_point_in_polygon(hole_poly[0], outer_poly) {
        group.push(hole)
      }
    }
    groups.push(group)
  }
  groups
}

///|
/// bezier_profiles groups flattened `BezierPath`s into outer loops and holes.
///
/// Outers are wound counter-clockwise and holes clockwise, matching
/// `collect_profiles`.
fn bezier_profiles(paths : Array[BezierPath]) -> Array[Profile2D] {
  bezier_path_groups(paths).map(fn(group) {
    let outer = force_ccw(flatten_bezier_path(group[0]))
    let holes = group
      .iter()
      .drop(1)
      .map(fn(path) { force_cw(flatten_bezier_path(path)) })
      .collect()
    Profile2D::{ outer, holes, }
  })
}

///|
/// compile_extruded_bezier_profile writes a B-Rep for an
/// `ExtrudedBezierProfile` by flattening its cubic Beziers into polylines and
/// delegating each outer/hole group to `compile_extruded_profile`.
pub fn compile_extruded_bezier_profile(
  ctx : StepContext,
  node : SceneNode,
  extrusion : ExtrudedBezierProfile,
  reverse~ : Bool = false,
) -> Array[@step.Ref] {
  if extrusion.height_mm == 0.0 {
    return []
  }
  let faces : Array[@step.Ref] = []
  for profile in bezier_profiles(extrusion.paths) {
    if profile.outer.length() < 3 {
      continue
    }
    let ext = ExtrudedProfile::{ profile, height_mm: extrusion.height_mm, }
    faces.push_iter(compile_extruded_profile(ctx, node, ext, reverse~).iter())
  }
  faces
}
