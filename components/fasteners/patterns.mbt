///|
/// High-level declarative fastener pattern builders (`HeatSetInsertPattern`,
/// `BoltCirclePattern`, `DowelPinPattern`) built on `@cad.PointPattern2D`.
///
/// Define a mounting pattern once (as a `ring`, `rect`, `grid`, `line`, or
/// custom `PointPattern2D`), then cut accurately sized blind pockets,
/// clearance holes, counterbores, or tap holes with a single method call —
/// zero `for` loops and zero manual trig.

///|
/// Standard 3D-printed heat-set insert pilot hole diameter (mm) for a metric
/// thread size (sized ~0.1–0.2 mm under insert knurled OD for strong melt flow).
pub fn heat_set_insert_pilot_diam_mm(size : @standards.MetricSize) -> Double {
  match size {
    @standards.M2 => 3.2
    @standards.M2_5 => 3.8
    @standards.M3 => 4.4
    @standards.M4 => 5.6
    @standards.M5 => 6.4
    @standards.M6 => 8.0
    @standards.M8 => 10.0
    _ => size.nominal_diameter_mm() * 1.45
  }
}

///|
/// Standard ISO 273 medium clearance hole diameter (mm) for a metric bolt size.
pub fn metric_clearance_hole_diam_mm(size : @standards.MetricSize) -> Double {
  match size {
    @standards.M2 => 2.4
    @standards.M2_5 => 2.9
    @standards.M3 => 3.4
    @standards.M4 => 4.5
    @standards.M5 => 5.5
    @standards.M6 => 6.6
    @standards.M8 => 9.0
    @standards.M10 => 11.0
    @standards.M12 => 13.5
    _ => size.nominal_diameter_mm() + 0.4
  }
}

///|
/// Standard coarse-metric tap-drill diameter (`major - pitch`) in mm.
pub fn metric_tap_drill_diam_mm(size : @standards.MetricSize) -> Double {
  size.nominal_diameter_mm() - size.coarse_pitch_mm()
}

///|
/// A reusable pattern of blind heat-set insert pockets sharing one metric
/// thread size, pocket depth, and `@cad.PointPattern2D`.
pub(all) struct HeatSetInsertPattern {
  size : @standards.MetricSize
  pattern : @cad.PointPattern2D
  pilot_diam_mm : Double
  depth_mm : Double
}

///|
/// Creates a `HeatSetInsertPattern` on any `@cad.PointPattern2D`.
pub fn HeatSetInsertPattern::on_pattern(
  size : @standards.MetricSize,
  pattern : @cad.PointPattern2D,
  depth_mm~ : Double = 6.0,
  pilot_diam_mm? : Double,
) -> HeatSetInsertPattern {
  {
    size,
    pattern,
    pilot_diam_mm: pilot_diam_mm.unwrap_or(heat_set_insert_pilot_diam_mm(size)),
    depth_mm,
  }
}

///|
/// Creates a circular ring of `count` heat-set insert pockets on a bolt circle
/// of diameter `bolt_circle_diam_mm`.
pub fn HeatSetInsertPattern::ring(
  size : @standards.MetricSize,
  count~ : Int32 = 4,
  bolt_circle_diam_mm~ : Double,
  depth_mm~ : Double = 6.0,
  phase_deg~ : Double = 0.0,
  center_x~ : Double = 0.0,
  center_y~ : Double = 0.0,
  pilot_diam_mm? : Double,
) -> HeatSetInsertPattern {
  HeatSetInsertPattern::on_pattern(
    size,
    @cad.PointPattern2D::ring(
      count,
      diam_mm=bolt_circle_diam_mm,
      phase_deg~,
      center_x~,
      center_y~,
    ),
    depth_mm~,
    pilot_diam_mm?,
  )
}

///|
/// Creates a 4-corner rectangular pattern (`width_mm` × `height_mm`) of
/// heat-set insert pockets (e.g. `32 × 32 mm` for a moteus C1 controller).
pub fn HeatSetInsertPattern::rect(
  size : @standards.MetricSize,
  width_mm~ : Double,
  height_mm~ : Double,
  depth_mm~ : Double = 6.0,
  center_x~ : Double = 0.0,
  center_y~ : Double = 0.0,
  pilot_diam_mm? : Double,
) -> HeatSetInsertPattern {
  HeatSetInsertPattern::on_pattern(
    size,
    @cad.PointPattern2D::rect(width_mm, height_mm, center_x~, center_y~),
    depth_mm~,
    pilot_diam_mm?,
  )
}

///|
/// Cuts blind heat-set insert pockets into `target` starting at face `z_mm`.
/// By default pockets extend into `+Z` (`z_mm .. z_mm + depth_mm`); pass
/// `into_negative_z=true` when cutting downward from a top face (`z_mm - depth_mm .. z_mm`).
pub fn HeatSetInsertPattern::cut_pockets_from(
  self : HeatSetInsertPattern,
  target : @cad.SceneNode,
  z_mm~ : Double = 0.0,
  into_negative_z~ : Bool = false,
  embed_mm~ : Double = 0.5,
  name? : String,
) -> @cad.SceneNode {
  let z0 = if into_negative_z { z_mm - self.depth_mm } else { z_mm - embed_mm }
  let total_h = self.depth_mm + embed_mm
  self.pattern.drill_holes(
    target,
    self.pilot_diam_mm,
    z0_mm=z0,
    depth_mm=total_h,
    name?,
  )
}

///|
/// A reusable pattern of ISO 4762 socket-head cap screw locations sharing one
/// metric size, nominal length, and `@cad.PointPattern2D`.
pub(all) struct BoltCirclePattern {
  size : @standards.MetricSize
  pattern : @cad.PointPattern2D
  length_mm : Double
}

///|
/// Creates a `BoltCirclePattern` on any `@cad.PointPattern2D`.
pub fn BoltCirclePattern::on_pattern(
  size : @standards.MetricSize,
  pattern : @cad.PointPattern2D,
  length_mm~ : Double = 12.0,
) -> BoltCirclePattern {
  { size, pattern, length_mm, }
}

///|
/// Creates a circular ring of `count` metric bolt locations on a bolt circle
/// of diameter `bolt_circle_diam_mm`.
pub fn BoltCirclePattern::ring(
  size : @standards.MetricSize,
  count~ : Int32 = 4,
  bolt_circle_diam_mm~ : Double,
  length_mm~ : Double = 12.0,
  phase_deg~ : Double = 0.0,
  center_x~ : Double = 0.0,
  center_y~ : Double = 0.0,
) -> BoltCirclePattern {
  BoltCirclePattern::on_pattern(
    size,
    @cad.PointPattern2D::ring(
      count,
      diam_mm=bolt_circle_diam_mm,
      phase_deg~,
      center_x~,
      center_y~,
    ),
    length_mm~,
  )
}

///|
/// Creates a 4-corner rectangular bolt pattern (`width_mm` × `height_mm`).
pub fn BoltCirclePattern::rect(
  size : @standards.MetricSize,
  width_mm~ : Double,
  height_mm~ : Double,
  length_mm~ : Double = 12.0,
  center_x~ : Double = 0.0,
  center_y~ : Double = 0.0,
) -> BoltCirclePattern {
  BoltCirclePattern::on_pattern(
    size,
    @cad.PointPattern2D::rect(width_mm, height_mm, center_x~, center_y~),
    length_mm~,
  )
}

///|
/// Cuts ISO 273 medium clearance holes (and optional SHCS head counterbores at
/// the top face `z0_mm + depth_mm`) through `target` in one call.
pub fn BoltCirclePattern::cut_clearance_holes(
  self : BoltCirclePattern,
  target : @cad.SceneNode,
  z0_mm~ : Double = 0.0,
  depth_mm~ : Double = 10.0,
  counterbore_depth_mm~ : Double = 0.0,
  embed_mm~ : Double = 0.5,
  name? : String,
) -> @cad.SceneNode {
  let out_name = name.unwrap_or(target.name)
  let clearance_d = metric_clearance_hole_diam_mm(self.size)
  let drilled = self.pattern.drill_holes(
    target,
    clearance_d,
    z0_mm=z0_mm - embed_mm,
    depth_mm=depth_mm + 2.0 * embed_mm,
    name=out_name,
  )
  if counterbore_depth_mm <= 0.0 {
    return drilled
  }
  let head_d = match @standards.iso4762_size(self.size) {
    Ok(s) => s.head_diameter_mm + 0.6
    Err(_) => clearance_d * 1.8
  }
  self.pattern.drill_holes(
    drilled,
    head_d,
    z0_mm=z0_mm + depth_mm - counterbore_depth_mm,
    depth_mm=counterbore_depth_mm + embed_mm,
    name=out_name,
  )
}

///|
/// Cuts metric tap-drill holes (`major - pitch`) into `target`.
pub fn BoltCirclePattern::cut_tap_holes(
  self : BoltCirclePattern,
  target : @cad.SceneNode,
  z0_mm~ : Double = 0.0,
  depth_mm~ : Double = 10.0,
  embed_mm~ : Double = 0.5,
  name? : String,
) -> @cad.SceneNode {
  let tap_d = metric_tap_drill_diam_mm(self.size)
  self.pattern.drill_holes(
    target,
    tap_d,
    z0_mm=z0_mm - embed_mm,
    depth_mm=depth_mm + embed_mm,
    name?,
  )
}

///|
/// A reusable pattern of hardened dowel pin locations (e.g. planetary carrier
/// pins or alignment dowels) built on `@cad.PointPattern2D`.
pub(all) struct DowelPinPattern {
  pin_diam_mm : Double
  pattern : @cad.PointPattern2D
  length_mm : Double
}

///|
/// Creates a `DowelPinPattern` on any `@cad.PointPattern2D`.
pub fn DowelPinPattern::on_pattern(
  pin_diam_mm~ : Double,
  pattern : @cad.PointPattern2D,
  length_mm~ : Double = 20.0,
) -> DowelPinPattern {
  { pin_diam_mm, pattern, length_mm, }
}

///|
/// Creates a circular ring of `count` dowel pins on a bolt circle of diameter
/// `bolt_circle_diam_mm`.
pub fn DowelPinPattern::ring(
  pin_diam_mm~ : Double,
  count~ : Int32 = 4,
  bolt_circle_diam_mm~ : Double,
  length_mm~ : Double = 20.0,
  phase_deg~ : Double = 0.0,
  center_x~ : Double = 0.0,
  center_y~ : Double = 0.0,
) -> DowelPinPattern {
  DowelPinPattern::on_pattern(
    pin_diam_mm~,
    @cad.PointPattern2D::ring(
      count,
      diam_mm=bolt_circle_diam_mm,
      phase_deg~,
      center_x~,
      center_y~,
    ),
    length_mm~,
  )
}

///|
/// Drills dowel pin holes (`pin_diam_mm + clearance_mm`) into `target`.
pub fn DowelPinPattern::cut_pin_holes(
  self : DowelPinPattern,
  target : @cad.SceneNode,
  z0_mm~ : Double = 0.0,
  depth_mm~ : Double = 10.0,
  clearance_mm~ : Double = 0.10,
  embed_mm~ : Double = 0.5,
  name? : String,
) -> @cad.SceneNode {
  self.pattern.drill_holes(
    target,
    self.pin_diam_mm + clearance_mm,
    z0_mm=z0_mm - embed_mm,
    depth_mm=depth_mm + 2.0 * embed_mm,
    name?,
  )
}

///|
/// Generates one `Female` `CylindricalBore` `@common.MateConnector` at each
/// pocket center on `z_mm` (named `"\{prefix}_0"`, `"\{prefix}_1"`, ...),
/// matching the exact pilot diameter and pocket depth.
pub fn HeatSetInsertPattern::mate_connectors(
  self : HeatSetInsertPattern,
  prefix~ : String = "insert",
  z_mm~ : Double = 0.0,
  axis~ : (Double, Double, Double) = (0.0, 0.0, 1.0),
) -> Array[@common.MateConnector] {
  let out : Array[@common.MateConnector] = []
  for i in 0..<self.pattern.points.length() {
    let (x, y) = self.pattern.points[i]
    out.push(
      @common.MateConnector::new(
        "\{prefix}_\{i}",
        placement=@common.Placement::translation(x, y, z_mm),
        axis~,
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=self.pilot_diam_mm,
        depth_mm=self.depth_mm,
        description="\{self.size.designation()} heat-set insert pocket",
      ),
    )
  }
  out
}

///|
/// Generates one `Female` `CylindricalBore` `@common.MateConnector` at each
/// bolt hole center on `z_mm` (named `"\{prefix}_0"`, `"\{prefix}_1"`, ...).
pub fn BoltCirclePattern::mate_connectors(
  self : BoltCirclePattern,
  prefix~ : String = "bolt",
  z_mm~ : Double = 0.0,
  axis~ : (Double, Double, Double) = (0.0, 0.0, 1.0),
  depth_mm~ : Double = 0.0,
) -> Array[@common.MateConnector] {
  let diam = metric_clearance_hole_diam_mm(self.size)
  let out : Array[@common.MateConnector] = []
  for i in 0..<self.pattern.points.length() {
    let (x, y) = self.pattern.points[i]
    out.push(
      @common.MateConnector::new(
        "\{prefix}_\{i}",
        placement=@common.Placement::translation(x, y, z_mm),
        axis~,
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=diam,
        depth_mm?=if depth_mm > 0.0 { Some(depth_mm) } else { None },
        description="\{self.size.designation()} bolt clearance hole",
      ),
    )
  }
  out
}

///|
/// Generates one `Female` `CylindricalBore` `@common.MateConnector` at each
/// dowel pin hole center on `z_mm` (named `"\{prefix}_0"`, `"\{prefix}_1"`, ...).
pub fn DowelPinPattern::mate_connectors(
  self : DowelPinPattern,
  prefix~ : String = "dowel",
  z_mm~ : Double = 0.0,
  axis~ : (Double, Double, Double) = (0.0, 0.0, 1.0),
  clearance_mm~ : Double = 0.10,
  depth_mm~ : Double = 0.0,
) -> Array[@common.MateConnector] {
  let diam = self.pin_diam_mm + clearance_mm
  let out : Array[@common.MateConnector] = []
  for i in 0..<self.pattern.points.length() {
    let (x, y) = self.pattern.points[i]
    out.push(
      @common.MateConnector::new(
        "\{prefix}_\{i}",
        placement=@common.Placement::translation(x, y, z_mm),
        axis~,
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=diam,
        depth_mm?=if depth_mm > 0.0 { Some(depth_mm) } else { None },
        description="Ø\{@cad.fmt_double(self.pin_diam_mm, Some(0.1))} mm dowel pin hole",
      ),
    )
  }
  out
}
