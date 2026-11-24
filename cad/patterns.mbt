///|
/// Declarative 2D point patterns (`ring`, `rect`, `grid`, `line`, `from_points`)
/// with fluent combinators and boolean-application helpers so callers never
/// need boilerplate `for` loops or manual `cos`/`sin` math to place holes,
/// bosses, inserts, bolts, dowel pins, or snap-fit connectors.

///|
/// A reusable 2D pattern of `(x, y)` coordinates in millimetres.
pub(all) struct PointPattern2D {
  points : Array[(Double, Double)]
}

///|
/// Creates a pattern from an explicit array of `(x, y)` coordinates (mm).
pub fn PointPattern2D::from_points(
  points : Array[(Double, Double)],
) -> PointPattern2D {
  { points: points.copy(), }
}

///|
/// Creates `count` evenly spaced points on a bolt circle of diameter `diam_mm`
/// centered at `(center_x, center_y)`, starting at `phase_deg`.
pub fn PointPattern2D::ring(
  count : Int32,
  diam_mm~ : Double,
  phase_deg~ : Double = 0.0,
  center_x~ : Double = 0.0,
  center_y~ : Double = 0.0,
) -> PointPattern2D {
  let pts : Array[(Double, Double)] = []
  if count <= 0 || diam_mm <= 0.0 {
    return { points: pts, }
  }
  let r = diam_mm / 2.0
  for i in 0..<count {
    let ang = (phase_deg + 360.0 * i.to_double() / count.to_double()) *
      @math.PI /
      180.0
    pts.push((center_x + r * @math.cos(ang), center_y + r * @math.sin(ang)))
  }
  { points: pts, }
}

///|
/// Creates a 4-corner rectangular pattern (`width_mm` × `height_mm`) centered
/// at `(center_x, center_y)` — ideal for PCB standoffs (e.g. moteus C1
/// 32 × 32 mm) and mounting plates.
pub fn PointPattern2D::rect(
  width_mm : Double,
  height_mm : Double,
  center_x~ : Double = 0.0,
  center_y~ : Double = 0.0,
) -> PointPattern2D {
  let hx = width_mm / 2.0
  let hy = height_mm / 2.0
  {
    points: [
      (center_x + hx, center_y - hy),
      (center_x - hx, center_y - hy),
      (center_x + hx, center_y + hy),
      (center_x - hx, center_y + hy),
    ],
  }
}

///|
/// Creates a `cols` × `rows` rectangular grid spaced by `pitch_x_mm` and
/// `pitch_y_mm`, centered at `(center_x, center_y)`.
pub fn PointPattern2D::grid(
  cols : Int32,
  rows : Int32,
  pitch_x_mm : Double,
  pitch_y_mm : Double,
  center_x~ : Double = 0.0,
  center_y~ : Double = 0.0,
) -> PointPattern2D {
  let pts : Array[(Double, Double)] = []
  if cols <= 0 || rows <= 0 {
    return { points: pts, }
  }
  let x0 = center_x - (cols - 1).to_double() * pitch_x_mm / 2.0
  let y0 = center_y - (rows - 1).to_double() * pitch_y_mm / 2.0
  for r in 0..<rows {
    for c in 0..<cols {
      pts.push(
        (x0 + c.to_double() * pitch_x_mm, y0 + r.to_double() * pitch_y_mm),
      )
    }
  }
  { points: pts, }
}

///|
/// Creates `count` evenly spaced points along a line at `angle_deg`, spaced by
/// `pitch_mm` and centered at `(center_x, center_y)`.
pub fn PointPattern2D::line(
  count : Int32,
  pitch_mm : Double,
  angle_deg~ : Double = 0.0,
  center_x~ : Double = 0.0,
  center_y~ : Double = 0.0,
) -> PointPattern2D {
  let pts : Array[(Double, Double)] = []
  if count <= 0 {
    return { points: pts, }
  }
  let rad = angle_deg * @math.PI / 180.0
  let ux = @math.cos(rad)
  let uy = @math.sin(rad)
  let half = (count - 1).to_double() * pitch_mm / 2.0
  for i in 0..<count {
    let s = i.to_double() * pitch_mm - half
    pts.push((center_x + s * ux, center_y + s * uy))
  }
  { points: pts, }
}

///|
/// Number of points in this pattern.
pub fn PointPattern2D::length(self : PointPattern2D) -> Int32 {
  self.points.length()
}

///|
/// Returns a new pattern translated by `(dx, dy)` millimetres.
pub fn PointPattern2D::translate(
  self : PointPattern2D,
  dx : Double,
  dy : Double,
) -> PointPattern2D {
  { points: self.points.map(fn(pt) { (pt.0 + dx, pt.1 + dy) }), }
}

///|
/// Returns a new pattern rotated counter-clockwise by `angle_deg` around the
/// origin.
pub fn PointPattern2D::rotate_deg(
  self : PointPattern2D,
  angle_deg : Double,
) -> PointPattern2D {
  let rad = angle_deg * @math.PI / 180.0
  let c = @math.cos(rad)
  let s = @math.sin(rad)
  {
    points: self.points.map(fn(pt) {
      (pt.0 * c - pt.1 * s, pt.0 * s + pt.1 * c)
    }),
  }
}

///|
/// Concatenates two patterns into one combined pattern.
pub fn PointPattern2D::combine(
  self : PointPattern2D,
  other : PointPattern2D,
) -> PointPattern2D {
  let pts = self.points.copy()
  for pt in other.points {
    pts.push(pt)
  }
  { points: pts, }
}

///|
/// Places a copy of `node` at every `(x, y, z_mm)` point in the pattern,
/// numbering each copy `"\{node.name}_0"`, `"\{node.name}_1"`, ...
pub fn PointPattern2D::place(
  self : PointPattern2D,
  node : SceneNode,
  z_mm~ : Double = 0.0,
) -> Array[SceneNode] {
  let out : Array[SceneNode] = []
  for i in 0..<self.points.length() {
    let (x, y) = self.points[i]
    out.push(node.with_name("\{node.name}_\{i}").translate(x~, y~, z=z_mm))
  }
  out
}

///|
/// Unions copies of `feature` at every `(x, y, z_mm)` point in this pattern
/// onto `target`, preserving `target`'s color.
pub fn PointPattern2D::union_onto(
  self : PointPattern2D,
  target : SceneNode,
  feature : SceneNode,
  z_mm~ : Double = 0.0,
  name? : String,
) -> SceneNode {
  if self.points.is_empty() {
    return target
  }
  let out_name = name.unwrap_or(target.name)
  let nodes : Array[SceneNode] = [target]
  for n in self.place(feature, z_mm~) {
    nodes.push(n)
  }
  union_all(nodes, name=out_name).with_color(target.color)
}

///|
/// Subtracts copies of `cutter` at every `(x, y, z_mm)` point in this pattern
/// from `target`, preserving `target`'s color.
pub fn PointPattern2D::cut_from(
  self : PointPattern2D,
  target : SceneNode,
  cutter : SceneNode,
  z_mm~ : Double = 0.0,
  name? : String,
) -> SceneNode {
  if self.points.is_empty() {
    return target
  }
  let out_name = name.unwrap_or(target.name)
  difference(target, self.place(cutter, z_mm~), name=out_name).with_color(
    target.color,
  )
}

///|
/// Drills cylindrical holes of diameter `hole_diam_mm` and length `depth_mm`
/// starting at `z0_mm` (extending in `+Z`) at every point in this pattern.
pub fn PointPattern2D::drill_holes(
  self : PointPattern2D,
  target : SceneNode,
  hole_diam_mm : Double,
  z0_mm~ : Double = -0.5,
  depth_mm~ : Double = 20.0,
  name? : String,
) -> SceneNode {
  let cutter = Cylinder::new(hole_diam_mm / 2.0, depth_mm).with_name("hole")
  self.cut_from(target, cutter, z_mm=z0_mm, name?)
}
