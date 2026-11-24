///|
/// Parameterized, support-free 45-degree revolved axial snap-fit connector for
/// permanently joining two stacked 3D-printed parts (such as concentric gears)
/// completely flush with zero glue.
///
/// Both the outward barb flare and the inward lead-in cone default to 45 deg
/// so the connector prints cleanly without supports in either vertical
/// orientation (+Z or -Z). One or more vertical flex slots (mandatory) turn the
/// revolved head into cantilever spring fingers that compress during insertion
/// and snap open into the female undercut without cracking the mating part.

///|
/// Validated parameters for an axial revolved snap-fit pin and its matching
/// subtractive female void.
pub(all) struct AxialSnapPinParams {
  /// Pin root radius at the mating face (z = 0).
  base_radius_mm : Double
  /// Tapered neck radius just below the 45-deg barb flare.
  neck_radius_mm : Double
  /// Axial height from the mating face (z = 0) to the start of the barb flare.
  neck_height_mm : Double
  /// Radial barb protrusion beyond `neck_radius_mm` (`head_radius = neck + undercut`).
  undercut_mm : Double
  /// Flat top tip radius of the pin head.
  tip_radius_mm : Double
  /// Outward barb flare angle from vertical (default 45 deg, support-free).
  flare_angle_deg : Double
  /// Inward lead-in cone angle from vertical (default 45 deg, support-free).
  lead_in_angle_deg : Double
  /// Radial clearance between the male pin and the female void (default 0.10 mm).
  clearance_mm : Double
  /// Extra axial clearance above the male tip inside the female pocket so the
  /// two mating faces always pull completely flush (default 0.30 mm).
  top_clearance_mm : Double
  /// Entry mouth chamfer at z = 0 on the female void (elephant-foot relief +
  /// smooth insertion funnel; default 0.35 mm).
  mouth_chamfer_mm : Double
  /// Number of vertical flex slots cut through the head (mandatory >= 1;
  /// 1 = 2-finger split pin, 2 = 4-finger cross-slotted pin).
  num_slots : Int32
  /// Width of each vertical flex slot (default 0.9 mm).
  slot_width_mm : Double
  /// Z height above the mating face where the flex slots terminate (leaving a
  /// solid root for shear/torsion strength; default 0.35 * neck_height_mm).
  slot_bottom_z_mm : Double
  /// Overlap extension below z = 0 for clean watertight boolean union/difference.
  embed_mm : Double
}

///|
/// Creates and validates an `AxialSnapPinParams` specification.
pub fn AxialSnapPinParams::new(
  base_radius_mm~ : Double = 3.0,
  neck_radius_mm~ : Double = 2.5,
  neck_height_mm~ : Double = 4.0,
  undercut_mm~ : Double = 0.30,
  tip_radius_mm~ : Double = 1.8,
  flare_angle_deg~ : Double = 45.0,
  lead_in_angle_deg~ : Double = 45.0,
  clearance_mm~ : Double = 0.10,
  top_clearance_mm~ : Double = 0.30,
  mouth_chamfer_mm~ : Double = 0.35,
  num_slots~ : Int32 = 2,
  slot_width_mm~ : Double = 0.9,
  slot_bottom_z_mm? : Double,
  embed_mm~ : Double = 0.5,
) -> Result[AxialSnapPinParams, @common.SpecError] {
  if base_radius_mm <= 0.0 || neck_radius_mm <= 0.0 {
    return Err(
      @common.SpecError::InvalidDimension(
        "snap pin base_radius_mm and neck_radius_mm must be > 0",
      ),
    )
  }
  if neck_radius_mm > base_radius_mm {
    return Err(
      @common.SpecError::InvalidDimension(
        "snap pin neck_radius_mm must be <= base_radius_mm",
      ),
    )
  }
  if neck_height_mm <= 0.0 {
    return Err(
      @common.SpecError::InvalidDimension("snap pin neck_height_mm must be > 0"),
    )
  }
  if undercut_mm <= 0.0 {
    return Err(
      @common.SpecError::InvalidDimension("snap pin undercut_mm must be > 0"),
    )
  }
  let head_r = neck_radius_mm + undercut_mm
  if tip_radius_mm <= 0.0 || tip_radius_mm >= head_r {
    return Err(
      @common.SpecError::InvalidDimension(
        "snap pin tip_radius_mm must be > 0 and < neck_radius_mm + undercut_mm",
      ),
    )
  }
  if flare_angle_deg <= 5.0 ||
    flare_angle_deg >= 85.0 ||
    lead_in_angle_deg <= 5.0 ||
    lead_in_angle_deg >= 85.0 {
    return Err(
      @common.SpecError::InvalidParameter(
        "snap pin flare_angle_deg and lead_in_angle_deg must be in (5, 85) deg",
      ),
    )
  }
  if clearance_mm < 0.0 || top_clearance_mm < 0.0 || mouth_chamfer_mm < 0.0 {
    return Err(
      @common.SpecError::InvalidDimension(
        "snap pin clearances and mouth_chamfer_mm must be >= 0",
      ),
    )
  }
  if mouth_chamfer_mm >= neck_height_mm {
    return Err(
      @common.SpecError::InvalidDimension(
        "snap pin mouth_chamfer_mm must be < neck_height_mm",
      ),
    )
  }
  if num_slots < 1 {
    return Err(
      @common.SpecError::InvalidParameter(
        "snap pin num_slots must be >= 1 (vertical flex slot is mandatory)",
      ),
    )
  }
  if slot_width_mm <= 0.0 || slot_width_mm >= neck_radius_mm {
    return Err(
      @common.SpecError::InvalidDimension(
        "snap pin slot_width_mm must be > 0 and < neck_radius_mm",
      ),
    )
  }
  let resolved_slot_bottom = match slot_bottom_z_mm {
    Some(z) => z
    None => neck_height_mm * 0.35
  }
  if resolved_slot_bottom < 0.0 || resolved_slot_bottom >= neck_height_mm {
    return Err(
      @common.SpecError::InvalidDimension(
        "snap pin slot_bottom_z_mm must be in [0, neck_height_mm)",
      ),
    )
  }
  if embed_mm < 0.0 {
    return Err(
      @common.SpecError::InvalidDimension("snap pin embed_mm must be >= 0"),
    )
  }
  Ok({
    base_radius_mm,
    neck_radius_mm,
    neck_height_mm,
    undercut_mm,
    tip_radius_mm,
    flare_angle_deg,
    lead_in_angle_deg,
    clearance_mm,
    top_clearance_mm,
    mouth_chamfer_mm,
    num_slots,
    slot_width_mm,
    slot_bottom_z_mm: resolved_slot_bottom,
    embed_mm,
  })
}

///|
/// Peak outer radius of the male barb head (`neck_radius_mm + undercut_mm`).
pub fn AxialSnapPinParams::head_radius_mm(self : AxialSnapPinParams) -> Double {
  self.neck_radius_mm + self.undercut_mm
}

///|
/// Axial height of the outward barb flare (`undercut_mm / tan(flare_angle)`).
pub fn AxialSnapPinParams::flare_height_mm(self : AxialSnapPinParams) -> Double {
  let rad = self.flare_angle_deg * @math.PI / 180.0
  self.undercut_mm / @math.tan(rad)
}

///|
/// Axial height of the inward lead-in cone (`(head_r - tip_r) / tan(lead_in)`).
pub fn AxialSnapPinParams::lead_in_height_mm(
  self : AxialSnapPinParams,
) -> Double {
  let rad = self.lead_in_angle_deg * @math.PI / 180.0
  (self.head_radius_mm() - self.tip_radius_mm) / @math.tan(rad)
}

///|
/// Total protrusion height of the male pin above the mating plane (`z = 0`).
pub fn AxialSnapPinParams::total_height_mm(self : AxialSnapPinParams) -> Double {
  self.neck_height_mm + self.flare_height_mm() + self.lead_in_height_mm()
}

///|
/// Total depth of the female void above the mating plane (`z = 0`).
pub fn AxialSnapPinParams::void_depth_mm(self : AxialSnapPinParams) -> Double {
  self.total_height_mm() + self.top_clearance_mm
}

///|
/// Returns `count` evenly spaced `(x, y)` positions on a circle of radius
/// `bolt_circle_radius_mm`, for placing 3–6 axial snap connectors around two
/// concentric gears.
pub fn axial_snap_ring_positions(
  count : Int32,
  bolt_circle_radius_mm : Double,
  phase_deg~ : Double = 0.0,
) -> Array[(Double, Double)] {
  let out : Array[(Double, Double)] = []
  if count <= 0 || bolt_circle_radius_mm <= 0.0 {
    return out
  }
  for i in 0..<count {
    let ang = (phase_deg + 360.0 * i.to_double() / count.to_double()) *
      @math.PI /
      180.0
    out.push(
      (
        bolt_circle_radius_mm * @math.cos(ang),
        bolt_circle_radius_mm * @math.sin(ang),
      ),
    )
  }
  out
}

///|
/// Builds the positive male snap-pin `SceneNode` (revolved tapered stem +
/// 45-deg barb + 45-deg lead-in cone with mandatory vertical flex slots
/// subtracted). Mating plane is `z = 0`; pin protrudes along `+Z`.
pub fn axial_snap_pin_male_node(
  params : AxialSnapPinParams,
  name~ : String = "axial_snap_pin_male",
  color~ : @cad.Rgb = @cad.Rgb::orange(),
) -> @cad.SceneNode {
  let z_neck = params.neck_height_mm
  let z_peak = z_neck + params.flare_height_mm()
  let z_tip = z_peak + params.lead_in_height_mm()
  let head_r = params.head_radius_mm()
  let pts : Array[@cad.Vec2] = []
  if params.embed_mm > @step.TOL_1E9 {
    pts.push((0.0, -params.embed_mm))
    pts.push((params.base_radius_mm, -params.embed_mm))
    pts.push((params.base_radius_mm, 0.0))
  } else {
    pts.push((0.0, 0.0))
    pts.push((params.base_radius_mm, 0.0))
  }
  pts.push((params.neck_radius_mm, z_neck))
  pts.push((head_r, z_peak))
  pts.push((params.tip_radius_mm, z_tip))
  pts.push((0.0, z_tip))
  let base_node = @cad.RevolvedProfile::polyline(pts)
    .as_shape()
    .with_name(name + "_blank")
    .with_color(color)

  let slot_len = 2.0 * head_r + 2.0
  let slot_h = z_tip - params.slot_bottom_z_mm + 1.0
  let cutters : Array[@cad.SceneNode] = []
  for si in 0..<params.num_slots {
    let ang_deg = 180.0 * si.to_double() / params.num_slots.to_double()
    let ang_rad = ang_deg * @math.PI / 180.0
    let hx = slot_len / 2.0
    let hy = params.slot_width_mm / 2.0
    let ca = @math.cos(ang_rad)
    let sa = @math.sin(ang_rad)
    // Rotate Cuboid (corner at origin) first, then translate its rotated
    // center back to (0, 0) so every flex slot cuts dead-center through the pin.
    let cutter = @cad.Cuboid::new(slot_len, params.slot_width_mm, slot_h)
      .with_name(name + "_slot_" + si.to_string())
      .rotate_z(ang_deg)
      .translate(
        x=-(hx * ca - hy * sa),
        y=-(hx * sa + hy * ca),
        z=params.slot_bottom_z_mm,
      )
    cutters.push(cutter)
  }
  @cad.difference(base_node, cutters, name~).with_color(color)
}

///|
/// Builds the negative subtractive female void `SceneNode` matching
/// `axial_snap_pin_male_node`. Subtract this solid from the mating gear at the
/// exact same `(x, y, z)` pose to create the snap-fit socket.
pub fn axial_snap_pin_female_void_node(
  params : AxialSnapPinParams,
  name~ : String = "axial_snap_pin_female_void",
  color~ : @cad.Rgb = @cad.Rgb::blue(),
) -> @cad.SceneNode {
  let z_neck = params.neck_height_mm
  let z_peak = z_neck + params.flare_height_mm()
  let z_tip = z_peak + params.lead_in_height_mm()
  let z_void_tip = z_tip + params.top_clearance_mm
  let f_base = params.base_radius_mm + params.clearance_mm
  let f_neck = params.neck_radius_mm + params.clearance_mm
  let f_head = params.head_radius_mm() + params.clearance_mm
  let f_tip = params.tip_radius_mm + params.clearance_mm
  let f_mouth = f_base + params.mouth_chamfer_mm

  let pts : Array[@cad.Vec2] = []
  if params.embed_mm > @step.TOL_1E9 {
    pts.push((0.0, -params.embed_mm))
    pts.push((f_mouth, -params.embed_mm))
    pts.push((f_mouth, 0.0))
  } else {
    pts.push((0.0, 0.0))
    pts.push((f_mouth, 0.0))
  }
  if params.mouth_chamfer_mm > @step.TOL_1E9 {
    pts.push((f_base, params.mouth_chamfer_mm))
  }
  pts.push((f_neck, z_neck))
  pts.push((f_head, z_peak))
  pts.push((f_tip, z_tip))
  if params.top_clearance_mm > @step.TOL_1E9 {
    pts.push((f_tip, z_void_tip))
  }
  pts.push((0.0, z_void_tip))
  @cad.RevolvedProfile::polyline(pts)
  .as_shape()
  .with_name(name)
  .with_color(color)
}

///|
/// A reusable pattern of axial snap-fit connectors sharing one `AxialSnapPinParams`
/// and one set of `(x, y)` coordinates, so the male pins and female sockets are
/// guaranteed to stay 100% aligned with zero `for` loops at the call site.
///
/// Example:
/// ```moonbit nocheck
/// let snap = @fasteners.AxialSnapFit::ring(
///   params,
///   count=4,
///   bolt_circle_diam_mm=24.0,
/// )
///
/// let gear_a = snap.attach_male_to(gear_a_blank, z_mm=8.0)
///
/// let gear_b = snap.cut_female_from(gear_b_blank, z_mm=0.0)
/// ```
pub(all) struct AxialSnapFit {
  params : AxialSnapPinParams
  positions : Array[(Double, Double)]
}

///|
/// Creates an `AxialSnapFit` pattern of `count` evenly spaced connectors on a
/// bolt circle of diameter `bolt_circle_diam_mm` centered at `(center_x, center_y)`.
pub fn AxialSnapFit::ring(
  params : AxialSnapPinParams,
  count~ : Int32 = 3,
  bolt_circle_diam_mm~ : Double,
  phase_deg~ : Double = 0.0,
  center_x~ : Double = 0.0,
  center_y~ : Double = 0.0,
) -> AxialSnapFit {
  let raw = axial_snap_ring_positions(
    count,
    bolt_circle_diam_mm / 2.0,
    phase_deg~,
  )
  let positions = raw.map(fn(pt) { (pt.0 + center_x, pt.1 + center_y) })
  { params, positions, }
}

///|
/// Creates an `AxialSnapFit` pattern from any `@cad.PointPattern2D` (`ring`,
/// `rect`, `grid`, `line`, or custom points).
pub fn AxialSnapFit::on_pattern(
  params : AxialSnapPinParams,
  pattern : @cad.PointPattern2D,
) -> AxialSnapFit {
  { params, positions: pattern.points.copy(), }
}

///|
/// Creates an `AxialSnapFit` pattern at explicit `(x, y)` coordinates.
pub fn AxialSnapFit::at_points(
  params : AxialSnapPinParams,
  positions : Array[(Double, Double)],
) -> AxialSnapFit {
  { params, positions, }
}

///|
/// Unions all positive male snap-pins in this pattern onto `base` at mating
/// plane `z_mm`. Set `flip_z=true` to point the pins along `-Z` instead of `+Z`.
pub fn AxialSnapFit::attach_male_to(
  self : AxialSnapFit,
  base : @cad.SceneNode,
  z_mm~ : Double = 0.0,
  flip_z~ : Bool = false,
  name? : String,
) -> @cad.SceneNode {
  let out_name = name.unwrap_or(base.name)
  let parts : Array[@cad.SceneNode] = [base]
  for i in 0..<self.positions.length() {
    let (px, py) = self.positions[i]
    let raw_pin = axial_snap_pin_male_node(
      self.params,
      name="\{out_name}_snap_male_\{i}",
      color=base.color,
    )
    let oriented = if flip_z { raw_pin.rotate_x(180.0) } else { raw_pin }
    parts.push(oriented.translate(x=px, y=py, z=z_mm))
  }
  @cad.union_all(parts, name=out_name).with_color(base.color)
}

///|
/// Subtracts all matching female 45-degree undercut sockets in this pattern
/// from `target` at mating plane `z_mm`. Set `flip_z=true` when the sockets
/// enter from a top face going downward (`-Z`).
pub fn AxialSnapFit::cut_female_from(
  self : AxialSnapFit,
  target : @cad.SceneNode,
  z_mm~ : Double = 0.0,
  flip_z~ : Bool = false,
  name? : String,
) -> @cad.SceneNode {
  let out_name = name.unwrap_or(target.name)
  let voids : Array[@cad.SceneNode] = []
  for i in 0..<self.positions.length() {
    let (px, py) = self.positions[i]
    let raw_void = axial_snap_pin_female_void_node(
      self.params,
      name="\{out_name}_snap_void_\{i}",
      color=target.color,
    )
    let oriented = if flip_z { raw_void.rotate_x(180.0) } else { raw_void }
    voids.push(oriented.translate(x=px, y=py, z=z_mm))
  }
  @cad.difference(target, voids, name=out_name).with_color(target.color)
}

///|
/// Convenience method that applies both halves of the snap-fit pattern to a
/// `(base, mating)` pair in one call, returning `(male_part, female_part)`.
pub fn AxialSnapFit::join_pair(
  self : AxialSnapFit,
  base : @cad.SceneNode,
  mating : @cad.SceneNode,
  base_z_mm~ : Double = 0.0,
  mating_z_mm~ : Double = 0.0,
  flip_male_z~ : Bool = false,
  flip_female_z~ : Bool = false,
) -> (@cad.SceneNode, @cad.SceneNode) {
  (
    self.attach_male_to(base, z_mm=base_z_mm, flip_z=flip_male_z),
    self.cut_female_from(mating, z_mm=mating_z_mm, flip_z=flip_female_z),
  )
}

///|
/// Builds the positive male axial snap-pin as a reusable `@common.Component`
/// with `"mating_face"` (`z = 0`) and `"tip"` (`z = total_height_mm`) mate
/// connectors.
pub fn axial_snap_pin_male(
  params : AxialSnapPinParams,
  name~ : String = "axial-snap-pin-male",
  color~ : @cad.Rgb = @cad.Rgb::orange(),
) -> @common.Component {
  let node = axial_snap_pin_male_node(params, name~, color~)
  let features = @common.FeatureRecord::new(
    modeled=[
      "tapered-stem", "45-deg-barb", "45-deg-lead-in", "vertical-flex-slots",
    ],
    approximated=[],
    omitted=[],
  )
  let metadata = @common.Metadata::new(
    designation="SNAP-PIN-R\{@cad.fmt_double(params.base_radius_mm, Some(0.1))}",
    standard="3D-printable 45-deg revolved axial snap-fit",
    family="axial snap-fit fastener",
    size="Ø\{@cad.fmt_double(params.base_radius_mm * 2.0, Some(0.1))} x \{@cad.fmt_double(params.total_height_mm(), Some(0.1))} mm",
    source="Parametric support-free 45-deg revolved split snap-pin (male).",
  )
  @common.Component::new(
    name~,
    metadata~,
    description="Support-free 45-degree revolved axial snap-fit male pin with vertical flex slots",
    features~,
  )
  .add_layer(node.shape, name="body", color~)
  .with_connector_unchecked(
    @common.MateConnector::new(
      "mating_face",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=params.base_radius_mm * 2.0,
      description="Flush mating plane on base part",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "tip",
      placement=@common.Placement::translation(
        0.0,
        0.0,
        params.total_height_mm(),
      ),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=params.tip_radius_mm * 2.0,
      description="Top tip of snap-pin head",
    ),
  )
}

///|
/// Builds the subtractive female snap-fit void as a reusable
/// `@common.Component` with a `"mating_face"` (`z = 0`) mate connector.
pub fn axial_snap_pin_female_void(
  params : AxialSnapPinParams,
  name~ : String = "axial-snap-pin-female-void",
  color~ : @cad.Rgb = @cad.Rgb::blue(),
) -> @common.Component {
  let node = axial_snap_pin_female_void_node(params, name~, color~)
  let features = @common.FeatureRecord::new(
    modeled=[
      "mouth-entry-chamfer", "tapered-socket", "45-deg-undercut-pocket", "tip-axial-clearance",
    ],
    approximated=[],
    omitted=[],
  )
  let metadata = @common.Metadata::new(
    designation="SNAP-VOID-R\{@cad.fmt_double(params.base_radius_mm, Some(0.1))}",
    standard="3D-printable 45-deg revolved axial snap-fit",
    family="axial snap-fit fastener",
    size="Ø\{@cad.fmt_double((params.base_radius_mm + params.clearance_mm) * 2.0, Some(0.1))} x \{@cad.fmt_double(params.void_depth_mm(), Some(0.1))} mm",
    source="Parametric support-free 45-deg revolved snap-pin socket void (female).",
  )
  @common.Component::new(
    name~,
    metadata~,
    description="Subtractive female socket void matching axial_snap_pin_male",
    features~,
  )
  .add_layer(node.shape, name="void", color~)
  .with_connector_unchecked(
    @common.MateConnector::new(
      "mating_face",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=(params.base_radius_mm + params.clearance_mm) * 2.0,
      depth_mm=params.void_depth_mm(),
      description="Flush mating plane on receiving part",
    ),
  )
}

///|
/// Generates one `Male` `CylindricalShaft` `@common.MateConnector` on the
/// contact plane `z_mm` for every male snap-pin in this pattern.
pub fn AxialSnapFit::male_connectors(
  self : AxialSnapFit,
  prefix~ : String = "snap_male",
  z_mm~ : Double = 0.0,
  flip_z~ : Bool = false,
) -> Array[@common.MateConnector] {
  let axis = if flip_z { (0.0, 0.0, -1.0) } else { (0.0, 0.0, 1.0) }
  let out : Array[@common.MateConnector] = []
  for i in 0..<self.positions.length() {
    let (x, y) = self.positions[i]
    out.push(
      @common.MateConnector::new(
        "\{prefix}_\{i}",
        placement=@common.Placement::translation(x, y, z_mm),
        axis~,
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=self.params.base_radius_mm * 2.0,
        description="Axial snap-fit male pin mating face",
      ),
    )
  }
  out
}

///|
/// Generates one `Female` `CylindricalBore` `@common.MateConnector` on the
/// contact plane `z_mm` for every female snap-fit socket in this pattern.
/// Outward face normal points along `-Z` when `flip_z=false` (socket enters
/// from the bottom face going `+Z`), so it snaps directly anti-parallel to
/// `male_connectors(flip_z=false)`.
pub fn AxialSnapFit::female_connectors(
  self : AxialSnapFit,
  prefix~ : String = "snap_female",
  z_mm~ : Double = 0.0,
  flip_z~ : Bool = false,
) -> Array[@common.MateConnector] {
  let axis = if flip_z { (0.0, 0.0, 1.0) } else { (0.0, 0.0, -1.0) }
  let out : Array[@common.MateConnector] = []
  for i in 0..<self.positions.length() {
    let (x, y) = self.positions[i]
    out.push(
      @common.MateConnector::new(
        "\{prefix}_\{i}",
        placement=@common.Placement::translation(x, y, z_mm),
        axis~,
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=(self.params.base_radius_mm + self.params.clearance_mm) *
          2.0,
        depth_mm=self.params.void_depth_mm(),
        description="Axial snap-fit female socket mating face",
      ),
    )
  }
  out
}
