///|
/// Builds a 2D closed teardrop profile centered at `(0, 0)` with circular
/// radius `radius` and a tangent triangular peak pointing along `+Y` whose two
/// straight sides rise at `overhang_deg` (default `45.0` degrees from
/// horizontal) for support-free FDM printing of horizontal bores.
///
/// Geometry:
/// - Tangent points sit at `(±r * sin(θ), r * cos(θ))` where `θ = overhang_deg`.
/// - The two tangent lines meet at `(0, r / cos(θ))` (for `θ = 45°`,
///   `y_peak = r * sqrt(2) ≈ 1.4142 * r`).
/// - The lower circular arc spans from `90° + θ` counterclockwise through
///   `-90°` to `90° - θ` (split into two arcs <= 180° for exact STEP B-Rep
///   compatibility).
pub fn teardrop_profile_segments(
  radius : Double,
  overhang_deg~ : Double = 45.0,
) -> Array[ProfileSegment] {
  let clamped_deg = if overhang_deg < 20.0 {
    20.0
  } else if overhang_deg > 70.0 {
    70.0
  } else {
    overhang_deg
  }
  let theta = clamped_deg * @math.PI / 180.0
  let sin_t = @math.sin(theta)
  let cos_t = @math.cos(theta)
  // Tangent points on upper-left and upper-right of the circle
  let tx = radius * sin_t
  let ty = radius * cos_t
  // Apex where the two 45-deg tangent lines meet along +Y
  let peak_y = radius / cos_t
  let p_left = (-tx, ty)
  let p_bottom = (0.0, -radius)
  let p_right = (tx, ty)
  let p_peak = (0.0, peak_y)
  // Counterclockwise closed profile:
  // 1. Upper-left tangent -> bottom (CCW circular arc, <= 180 deg)
  // 2. Bottom -> upper-right tangent (CCW circular arc, <= 180 deg)
  // 3. Upper-right tangent -> peak (+Y)
  // 4. Peak -> upper-left tangent
  [
    ProfileSegment::SegmentArc(p_left, p_bottom, (0.0, 0.0)),
    ProfileSegment::SegmentArc(p_bottom, p_right, (0.0, 0.0)),
    ProfileSegment::SegmentLine(p_right, p_peak),
    ProfileSegment::SegmentLine(p_peak, p_left),
  ]
}

///|
/// Extrudes an exact analytical B-Rep teardrop bore along `+Z` (`0..length`)
/// with its 45-degree self-supporting peak pointing along `+Y`.
pub fn teardrop_bore(
  radius : Double,
  length : Double,
  overhang_deg~ : Double = 45.0,
  name~ : String = "teardrop_bore",
) -> SceneNode {
  let segs = teardrop_profile_segments(radius, overhang_deg~)
  ExtrudedArcProfile::new(segs, length).as_shape().with_name(name)
}

///|
/// Builds a horizontal bore cutter along `+Z` (`0..length`).
/// When `fdm` is `true`, emits a 45-degree teardrop bore (peak along `+Y`) so
/// the horizontal hole prints without supports on FDM printers; otherwise emits
/// an exact circular `Cylinder` (for SLS, CNC, or nominal CAD).
pub fn horizontal_bore(
  radius : Double,
  length : Double,
  fdm~ : Bool = false,
  overhang_deg~ : Double = 45.0,
  name~ : String = "horizontal_bore",
) -> SceneNode {
  if fdm {
    teardrop_bore(radius, length, overhang_deg~, name~)
  } else {
    Cylinder::new(radius, length).with_name(name)
  }
}
