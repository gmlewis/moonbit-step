///|
/// Parametric multi-disk cycloidal reducer (`gmlewis/step/components/cycloidal`).
///
/// Models a compact, balanced cycloidal drive stage along `+Z` (native print-flat
/// frame, or `+Y` when `y_up=true`):
///
/// - `num_disks` (default 2, 180° out of phase) identical-lobe cycloidal disks
///   whose eccentric centers of mass sum to zero, cancelling radial vibration.
/// - `num_lobes` lobes per disk meshing with `num_lobes + 1` fixed outer ring
///   pins, giving a signed gear ratio of `-1 / num_lobes` (output rotates
///   opposite to the input at `1 / num_lobes` speed).
/// - A phased eccentric input shaft driving the disks through eccentric bearings.
/// - An output carrier flange with `output_pin_count` drive pins engaging the
///   enlarged circular holes (`r_out + e + tol`) in every cycloidal disk.

///|
const CYC_PI : Double = 3.141592653589793

///|
const CYC_TWO_PI : Double = 6.283185307179586

///|
/// Input parameters for a parametric cycloidal stage.
pub(all) struct CycloidalParams {
  /// Number of lobes on each cycloidal disk (`N >= 3`). Ring has `N + 1` pins.
  /// Signed reduction ratio is `-N` (output rotates opposite to input).
  num_lobes : Int32
  /// Pitch radius `R` of the fixed outer ring pin circle, in mm.
  pin_circle_radius_mm : Double
  /// Radius `r_p` of each outer ring pin / roller, in mm.
  ring_pin_radius_mm : Double
  /// Input cam eccentricity `e`, in mm.
  eccentricity_mm : Double
  /// Number of phase-opposed cycloidal disks (`1`, `2` at 180°, or `3` at 120°).
  /// Default is `2` so radial unbalance forces cancel.
  num_disks : Int32
  /// Axial thickness of each cycloidal disk, in mm.
  disk_thickness_mm : Double
  /// Axial gap between adjacent phased disks, in mm.
  disk_gap_mm : Double
  /// Number of output carrier drive pins (`>= 3`, even recommended for 2-disk).
  output_pin_count : Int32
  /// Pitch radius `R_out` of the output carrier pins, in mm.
  output_pin_circle_radius_mm : Double
  /// Radius `r_out` of each output carrier pin, in mm.
  output_pin_radius_mm : Double
  /// Input shaft bore radius in the eccentric hub, in mm.
  input_bore_radius_mm : Double
  /// Outer radius of the eccentric bearing pressed into each disk center, in mm.
  eccentric_bearing_outer_radius_mm : Double
  /// Radial wall thickness outside the outer ring pins, in mm.
  outer_wall_mm : Double
  /// Radial mesh and hole clearance, in mm.
  tolerance_mm : Double
  /// Curve samples per lobe along the cycloid profile (`>= 8`).
  samples_per_lobe : Int32
}

///|
/// Builds and validates `CycloidalParams`.
pub fn CycloidalParams::new(
  num_lobes~ : Int32 = 11,
  pin_circle_radius_mm~ : Double = 42.0,
  ring_pin_radius_mm~ : Double = 3.0,
  eccentricity_mm~ : Double = 1.5,
  num_disks~ : Int32 = 2,
  disk_thickness_mm~ : Double = 8.0,
  disk_gap_mm~ : Double = 1.0,
  output_pin_count~ : Int32 = 6,
  output_pin_circle_radius_mm~ : Double = 24.0,
  output_pin_radius_mm~ : Double = 3.0,
  input_bore_radius_mm~ : Double = 4.1,
  eccentric_bearing_outer_radius_mm~ : Double = 11.0,
  outer_wall_mm~ : Double = 6.0,
  tolerance_mm~ : Double = 0.15,
  samples_per_lobe~ : Int32 = 16,
) -> Result[CycloidalParams, @common.SpecError] {
  if num_lobes < 3 {
    return Err(@common.InvalidParameter("num_lobes must be >= 3"))
  }
  if pin_circle_radius_mm <= 0.0 {
    return Err(
      @common.InvalidParameter("pin_circle_radius_mm must be positive"),
    )
  }
  if ring_pin_radius_mm <= 0.0 {
    return Err(@common.InvalidParameter("ring_pin_radius_mm must be positive"))
  }
  if eccentricity_mm <= 0.0 {
    return Err(@common.InvalidParameter("eccentricity_mm must be positive"))
  }
  if num_disks < 1 || num_disks > 3 {
    return Err(@common.InvalidParameter("num_disks must be 1, 2, or 3"))
  }
  if disk_thickness_mm <= 0.0 {
    return Err(@common.InvalidParameter("disk_thickness_mm must be positive"))
  }
  if disk_gap_mm < 0.0 {
    return Err(@common.InvalidParameter("disk_gap_mm must be >= 0"))
  }
  if output_pin_count < 3 {
    return Err(@common.InvalidParameter("output_pin_count must be >= 3"))
  }
  if output_pin_circle_radius_mm <= 0.0 || output_pin_radius_mm <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "output pin circle radius and pin radius must be positive",
      ),
    )
  }
  if input_bore_radius_mm <= 0.0 || eccentric_bearing_outer_radius_mm <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "input bore and eccentric bearing radii must be positive",
      ),
    )
  }
  if outer_wall_mm <= 0.0 {
    return Err(@common.InvalidParameter("outer_wall_mm must be positive"))
  }
  if tolerance_mm < 0.0 {
    return Err(@common.InvalidParameter("tolerance_mm must be >= 0"))
  }
  if samples_per_lobe < 8 {
    return Err(@common.InvalidParameter("samples_per_lobe must be >= 8"))
  }
  // Cycloid sharpness factor k = e * (N + 1) / R must stay safely below 1.0
  // to avoid cusps on the base epitrochoid.
  let z_ring = (num_lobes + 1).to_double()
  let k = eccentricity_mm * z_ring / pin_circle_radius_mm
  if k >= 0.85 {
    return Err(
      @common.InvalidParameter(
        "eccentricity_mm * (num_lobes + 1) / pin_circle_radius_mm = \{k} must be < 0.85 to avoid cusping",
      ),
    )
  }
  // Ring pins must not overlap each other on the pitch circle.
  let pin_chord = 2.0 * pin_circle_radius_mm * @math.sin(CYC_PI / z_ring)
  if 2.0 * ring_pin_radius_mm >= pin_chord - 0.5 {
    return Err(
      @common.InvalidParameter(
        "ring_pin_radius_mm too large: adjacent ring pins would overlap (chord \{pin_chord} mm)",
      ),
    )
  }
  // Check minimum radius of curvature at the concave valley so the inward
  // offset by (ring_pin_radius_mm + tolerance_mm) cannot self-intersect.
  let r_eff = ring_pin_radius_mm + tolerance_mm
  let denom = pin_circle_radius_mm * pin_circle_radius_mm +
    eccentricity_mm * eccentricity_mm * z_ring * z_ring * z_ring -
    eccentricity_mm * pin_circle_radius_mm * z_ring * (z_ring + 1.0)
  if denom > 1.0e-9 {
    let diff = pin_circle_radius_mm - eccentricity_mm * z_ring
    let rho_valley = diff * diff * diff / denom
    if r_eff >= rho_valley * 0.98 {
      return Err(
        @common.InvalidParameter(
          "ring_pin_radius_mm + tolerance_mm (\{r_eff} mm) exceeds valley curvature radius (\{rho_valley} mm); reduce ring_pin_radius_mm or eccentricity_mm",
        ),
      )
    }
  }
  // Eccentric cam wall check: input shaft bore must fit inside the eccentric
  // bearing inner/outer envelope with margin for the eccentric offset.
  if input_bore_radius_mm + eccentricity_mm >=
    eccentric_bearing_outer_radius_mm - 1.0 {
    return Err(
      @common.InvalidParameter(
        "input_bore_radius_mm + eccentricity_mm does not fit inside eccentric_bearing_outer_radius_mm",
      ),
    )
  }
  // Output pin hole clearance checks inside the cycloidal disk.
  let out_hole_r = output_pin_radius_mm + eccentricity_mm + tolerance_mm
  if output_pin_circle_radius_mm - out_hole_r <=
    eccentric_bearing_outer_radius_mm + 1.5 {
    return Err(
      @common.InvalidParameter(
        "output pin holes collide with eccentric bearing bore; increase output_pin_circle_radius_mm or reduce eccentric_bearing_outer_radius_mm",
      ),
    )
  }
  let out_chord = 2.0 *
    output_pin_circle_radius_mm *
    @math.sin(CYC_PI / output_pin_count.to_double())
  if 2.0 * out_hole_r >= out_chord - 1.5 {
    return Err(
      @common.InvalidParameter(
        "output pin holes overlap each other; reduce output_pin_count or output_pin_radius_mm",
      ),
    )
  }
  let disk_valley_r = pin_circle_radius_mm - eccentricity_mm - r_eff
  if output_pin_circle_radius_mm + out_hole_r >= disk_valley_r - 2.0 {
    return Err(
      @common.InvalidParameter(
        "output pin holes break through cycloidal disk valley; reduce output_pin_circle_radius_mm or increase pin_circle_radius_mm",
      ),
    )
  }
  Ok({
    num_lobes,
    pin_circle_radius_mm,
    ring_pin_radius_mm,
    eccentricity_mm,
    num_disks,
    disk_thickness_mm,
    disk_gap_mm,
    output_pin_count,
    output_pin_circle_radius_mm,
    output_pin_radius_mm,
    input_bore_radius_mm,
    eccentric_bearing_outer_radius_mm,
    outer_wall_mm,
    tolerance_mm,
    samples_per_lobe,
  })
}

///|
/// Derived geometric dimensions of a cycloidal stage.
pub(all) struct CycloidalLayout {
  params : CycloidalParams
  /// Number of fixed outer ring pins (`num_lobes + 1`).
  ring_pin_count : Int32
  /// Signed reduction ratio (`-num_lobes`: output turns opposite to input).
  signed_reduction : Double
  /// Magnitude of the reduction ratio (`num_lobes`).
  reduction_ratio : Double
  /// Radius of each output-pin clearance hole in the cycloidal disks.
  output_hole_radius_mm : Double
  /// Minimum (valley) radius of a cycloidal disk profile.
  disk_valley_radius_mm : Double
  /// Maximum (crest) radius of a cycloidal disk profile.
  disk_crest_radius_mm : Double
  /// Inner bore radius of the outer pin housing ring (clears disk crests + e).
  ring_inner_radius_mm : Double
  /// Outer radius of the integrated outer pin housing ring.
  ring_outer_radius_mm : Double
  /// Total axial height of the disk stack (`num_disks * t + (num_disks - 1) * gap`).
  stack_length_mm : Double
  /// Z-start offsets of each cycloidal disk within the stack.
  disk_z_offsets_mm : Array[Double]
  /// Eccentric phase angle of each disk in radians (`2*pi*d / num_disks`).
  disk_phase_rad : Array[Double]
  /// Ring pin center coordinates `(x, y)` in the housing frame.
  ring_pins : Array[(Double, Double)]
  /// Output pin nominal coordinates `(x, y)` at `input_deg = 0`.
  output_pins : Array[(Double, Double)]
}

///|
/// Computes the derived layout of a cycloidal stage.
pub fn cycloidal_layout(params : CycloidalParams) -> CycloidalLayout {
  let ring_pin_count = params.num_lobes + 1
  let reduction_ratio = params.num_lobes.to_double()
  let signed_reduction = -reduction_ratio
  let r_eff = params.ring_pin_radius_mm + params.tolerance_mm
  let output_hole_radius_mm = params.output_pin_radius_mm +
    params.eccentricity_mm +
    params.tolerance_mm
  let disk_valley_radius_mm = params.pin_circle_radius_mm -
    params.eccentricity_mm -
    r_eff
  let disk_crest_radius_mm = params.pin_circle_radius_mm +
    params.eccentricity_mm -
    r_eff
  // Housing bore sits at pin_circle_radius + ring_pin_radius (pins are recessed
  // halfway into the outer ring wall so they cannot fall inward).
  let ring_inner_radius_mm = params.pin_circle_radius_mm +
    params.ring_pin_radius_mm * 0.25
  let ring_outer_radius_mm = params.pin_circle_radius_mm +
    params.ring_pin_radius_mm +
    params.outer_wall_mm
  let stack_length_mm = params.num_disks.to_double() * params.disk_thickness_mm +
    (params.num_disks - 1).to_double() * params.disk_gap_mm
  let disk_z_offsets_mm : Array[Double] = []
  let disk_phase_rad : Array[Double] = []
  for d in 0..<params.num_disks {
    disk_z_offsets_mm.push(
      d.to_double() * (params.disk_thickness_mm + params.disk_gap_mm),
    )
    disk_phase_rad.push(
      CYC_TWO_PI * d.to_double() / params.num_disks.to_double(),
    )
  }
  let ring_pins : Array[(Double, Double)] = []
  for i in 0..<ring_pin_count {
    let a = CYC_TWO_PI * i.to_double() / ring_pin_count.to_double()
    ring_pins.push(
      (
        params.pin_circle_radius_mm * @math.cos(a),
        params.pin_circle_radius_mm * @math.sin(a),
      ),
    )
  }
  let output_pins : Array[(Double, Double)] = []
  for j in 0..<params.output_pin_count {
    let a = CYC_TWO_PI * j.to_double() / params.output_pin_count.to_double()
    output_pins.push(
      (
        params.output_pin_circle_radius_mm * @math.cos(a),
        params.output_pin_circle_radius_mm * @math.sin(a),
      ),
    )
  }
  {
    params,
    ring_pin_count,
    signed_reduction,
    reduction_ratio,
    output_hole_radius_mm,
    disk_valley_radius_mm,
    disk_crest_radius_mm,
    ring_inner_radius_mm,
    ring_outer_radius_mm,
    stack_length_mm,
    disk_z_offsets_mm,
    disk_phase_rad,
    ring_pins,
    output_pins,
  }
}

///|
/// Pose of one cycloidal disk in the housing frame at a given input angle.
pub(all) struct CycloidalDiskPose {
  /// Disk center X offset in mm (`e * cos(theta + phase)`).
  center_x_mm : Double
  /// Disk center Y offset in mm (`e * sin(theta + phase)`).
  center_y_mm : Double
  /// Disk rotation angle in radians (`-theta / num_lobes`).
  rotation_rad : Double
  /// Disk lobe profile phase offset in radians (`-phase / num_lobes`).
  lobe_phase_rad : Double
}

///|
/// Kinematic state of the cycloidal stage for a given input angle.
pub(all) struct CycloidalKinematics {
  input_rad : Double
  output_rad : Double
  disks : Array[CycloidalDiskPose]
}

///|
/// Evaluates the exact kinematic poses of all disks and the output carrier
/// for a given `input_deg` rotation of the eccentric input shaft.
pub fn cycloidal_kinematics(
  layout : CycloidalLayout,
  input_deg : Double,
) -> CycloidalKinematics {
  let theta = input_deg * CYC_PI / 180.0
  let n = layout.params.num_lobes.to_double()
  let e = layout.params.eccentricity_mm
  let output_rad = -theta / n
  let disks : Array[CycloidalDiskPose] = []
  for phase in layout.disk_phase_rad {
    let a = theta + phase
    disks.push({
      center_x_mm: e * @math.cos(a),
      center_y_mm: e * @math.sin(a),
      rotation_rad: output_rad,
      lobe_phase_rad: -phase / n,
    })
  }
  { input_rad: theta, output_rad, disks, }
}

///|
/// Generates the closed 2D CCW epitrochoid offset outline `(x, y)` of a
/// cycloidal disk in its local body frame, with optional `lobe_phase_rad`
/// rotation applied to the lobes (keeping output-pin holes aligned with the
/// output carrier across all phased disks).
pub fn cycloidal_disk_outline(
  params : CycloidalParams,
  lobe_phase_rad~ : Double = 0.0,
) -> Array[(Double, Double)] {
  let n = params.num_lobes
  let z = (n + 1).to_double()
  let r = params.pin_circle_radius_mm
  let e = params.eccentricity_mm
  let r_eff = params.ring_pin_radius_mm + params.tolerance_mm
  let total_pts = n * params.samples_per_lobe
  let c_rot = @math.cos(lobe_phase_rad)
  let s_rot = @math.sin(lobe_phase_rad)
  let pts : Array[(Double, Double)] = []
  for i in 0..<total_pts {
    let t = CYC_TWO_PI * i.to_double() / total_pts.to_double()
    let x0 = r * @math.cos(t) - e * @math.cos(z * t)
    let y0 = r * @math.sin(t) - e * @math.sin(z * t)
    let dx = -r * @math.sin(t) + e * z * @math.sin(z * t)
    let dy = r * @math.cos(t) - e * z * @math.cos(z * t)
    let norm = (dx * dx + dy * dy).sqrt()
    // Inward normal for CCW curve is (-dy, dx) / norm.
    let nx = -dy / norm
    let ny = dx / norm
    let lx = x0 + r_eff * nx
    let ly = y0 + r_eff * ny
    let rx = lx * c_rot - ly * s_rot
    let ry = lx * s_rot + ly * c_rot
    pts.push((rx, ry))
  }
  pts
}

///|
fn cyc_circle_segments_at(
  cx : Double,
  cy : Double,
  radius : Double,
  cw : Bool,
) -> Array[@cad.ProfileSegment] {
  // Four concentric quarter arcs forming a closed circle centered at (cx, cy).
  let p0 : @cad.Vec2 = (cx + radius, cy)
  let p1 : @cad.Vec2 = (cx, cy + radius)
  let p2 : @cad.Vec2 = (cx - radius, cy)
  let p3 : @cad.Vec2 = (cx, cy - radius)
  let center : @cad.Vec2 = (cx, cy)
  if cw {
    [
      @cad.SegmentArc(p0, p3, center),
      @cad.SegmentArc(p3, p2, center),
      @cad.SegmentArc(p2, p1, center),
      @cad.SegmentArc(p1, p0, center),
    ]
  } else {
    [
      @cad.SegmentArc(p0, p1, center),
      @cad.SegmentArc(p1, p2, center),
      @cad.SegmentArc(p2, p3, center),
      @cad.SegmentArc(p3, p0, center),
    ]
  }
}

///|
fn cyc_disk_shape(
  layout : CycloidalLayout,
  lobe_phase_rad : Double,
) -> @cad.Shape {
  let outline = cycloidal_disk_outline(layout.params, lobe_phase_rad~)
  let outer_segs = @gears.arc_outline_runs(outline)
  let holes : Array[Array[@cad.ProfileSegment]] = []
  // Center eccentric bearing bore (CCW hole, as required by ExtrudedArcProfile).
  holes.push(
    cyc_circle_segments_at(
      0.0,
      0.0,
      layout.params.eccentric_bearing_outer_radius_mm,
      false,
    ),
  )
  // Output carrier pin holes (CCW holes).
  for pin in layout.output_pins {
    holes.push(
      cyc_circle_segments_at(pin.0, pin.1, layout.output_hole_radius_mm, false),
    )
  }
  @cad.ExtrudedArcProfile::new(
    outer_segs,
    layout.params.disk_thickness_mm,
    holes~,
  ).as_shape()
}

///|
fn cyc_outer_ring_shape(layout : CycloidalLayout) -> @cad.Shape {
  // Smooth cylindrical outer ring shell whose inner bore clears the disks and
  // retains the outer ring pins.
  @cad.ExtrudedArcProfile::new(
    @gears.arc_circle_segments(2.0 * layout.ring_outer_radius_mm),
    layout.stack_length_mm,
    holes=[cyc_circle_segments_at(0.0, 0.0, layout.ring_inner_radius_mm, false)],
  ).as_shape()
}

///|
/// Builds a complete parametric cycloidal gearbox stage as a `@common.Component`
/// with named layers (`ring`, `ring-pin-*`, `disk-*`, `eccentric-cam-*`,
/// `output-pin-*`) and mate connectors.
///
/// The native frame has the shaft along `+Z` (print-flat) from `z = 0` to
/// `z = layout.stack_length_mm`. Pass `y_up=true` to rotate to `+Y` up.
pub fn cycloidal_gearbox(
  params : CycloidalParams,
  input_deg~ : Double = 0.0,
  y_up~ : Bool = false,
) -> Result[@common.Component, @common.SpecError] {
  let layout = cycloidal_layout(params)
  let kin = cycloidal_kinematics(layout, input_deg)
  let name = "cycloidal-n\{params.num_lobes}-d\{params.num_disks}-r\{@cad.fmt_double(params.pin_circle_radius_mm, None)}"
  let features = @common.FeatureRecord::new(
    modeled=[
      "phased-cycloidal-disks", "outer-ring-housing", "outer-ring-pins", "phased-eccentric-cams",
      "output-drive-pins",
    ],
    approximated=[
      @common.Approximation::new(
        feature="epitrochoid-lobe-outline",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=0.0,
        control="\{params.samples_per_lobe} samples per lobe fitted with smooth arc runs",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="roller-bearing-balls",
        reason="eccentric bearings are represented by their bore/cam envelope",
      ),
    ],
  )
  let mut comp = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Cycloidal reducer \{params.num_lobes}:1 (\{params.num_disks} phased disks, R=\{@cad.fmt_double(params.pin_circle_radius_mm, None)} mm, e=\{@cad.fmt_double(params.eccentricity_mm, None)} mm)",
      family="cycloidal gearbox",
      size="n\{params.num_lobes}-\{params.num_disks}d",
      length_mm=layout.stack_length_mm,
      source="Parametric multi-disk cycloidal reducer with 180-deg/120-deg phase balance.",
    ),
    description="Parametric cycloidal drive stage with phase-opposed cycloidal disks to cancel radial vibration, fixed outer pin ring, phased eccentric cams, and output drive pins.",
    features~,
  )
  // Outer housing ring.
  comp = comp.add_layer(
    cyc_outer_ring_shape(layout),
    name="ring",
    color=@cad.Rgb::grey(),
    placement=@common.Placement::identity(),
  )
  // Fixed outer ring pins.
  for i in 0..<layout.ring_pins.length() {
    let (px, py) = layout.ring_pins[i]
    let pin_shape = @cad.Cylinder::new(
      2.0 * params.ring_pin_radius_mm,
      layout.stack_length_mm,
    )
    comp = comp.add_layer(
      pin_shape,
      name="ring-pin-\{i + 1}",
      color=@cad.Rgb::new(0.75, 0.78, 0.82),
      placement=@common.Placement::translation(px, py, 0.0),
    )
  }
  // Phased cycloidal disks and their eccentric input cams.
  let disk_colors = [
    @cad.Rgb::blue(),
    @cad.Rgb::new(0.15, 0.72, 0.45),
    @cad.Rgb::new(0.75, 0.35, 0.85),
  ]
  for d in 0..<params.num_disks {
    let pose = kin.disks[d]
    let z0 = layout.disk_z_offsets_mm[d]
    let disk_shape = cyc_disk_shape(layout, pose.lobe_phase_rad)
    let rot_deg = pose.rotation_rad * 180.0 / CYC_PI
    comp = comp.add_layer(
      disk_shape,
      name="disk-\{d + 1}",
      color=disk_colors[d % disk_colors.length()],
      placement=@common.Placement::at(
        pose.center_x_mm,
        pose.center_y_mm,
        z0,
        rz=rot_deg,
      ),
    )
    // Eccentric cam lobe for disk d (outer diameter fits eccentric bearing bore,
    // bored on the input shaft axis so the cam is genuinely eccentric).
    let cam_outer_r = params.eccentric_bearing_outer_radius_mm * 0.65
    let cam_outer_r_safe = if cam_outer_r >
      params.input_bore_radius_mm + params.eccentricity_mm + 0.8 {
      cam_outer_r
    } else {
      params.eccentric_bearing_outer_radius_mm - 0.5
    }
    let phase_angle = kin.input_rad + layout.disk_phase_rad[d]
    let bore_cx = -params.eccentricity_mm * @math.cos(phase_angle)
    let bore_cy = -params.eccentricity_mm * @math.sin(phase_angle)
    let cam_shape = @cad.ExtrudedArcProfile::new(
      @gears.arc_circle_segments(2.0 * cam_outer_r_safe),
      params.disk_thickness_mm,
      holes=[
        cyc_circle_segments_at(
          bore_cx,
          bore_cy,
          params.input_bore_radius_mm,
          false,
        ),
      ],
    ).as_shape()
    comp = comp.add_layer(
      cam_shape,
      name="eccentric-cam-\{d + 1}",
      color=@cad.Rgb::orange(),
      placement=@common.Placement::translation(
        pose.center_x_mm,
        pose.center_y_mm,
        z0,
      ),
    )
  }
  // Output carrier drive pins passing through all disks.
  let c_out = @math.cos(kin.output_rad)
  let s_out = @math.sin(kin.output_rad)
  for j in 0..<layout.output_pins.length() {
    let (ox0, oy0) = layout.output_pins[j]
    let ox = ox0 * c_out - oy0 * s_out
    let oy = ox0 * s_out + oy0 * c_out
    let out_pin = @cad.Cylinder::new(
      2.0 * params.output_pin_radius_mm,
      layout.stack_length_mm,
    )
    comp = comp.add_layer(
      out_pin,
      name="output-pin-\{j + 1}",
      color=@cad.Rgb::new(0.85, 0.85, 0.90),
      placement=@common.Placement::translation(ox, oy, 0.0),
    )
  }
  // Mate connectors along +Z.
  comp = comp
    .with_connector_unchecked(
      @common.MateConnector::new(
        "ring-outer-seat",
        placement=@common.Placement::identity(),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=2.0 * layout.ring_outer_radius_mm,
        depth_mm=layout.stack_length_mm,
        description="outer housing ring cylindrical seat",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "ring-face-a",
        placement=@common.Placement::identity(),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * layout.ring_outer_radius_mm,
        description="input-side face of outer ring (z = 0)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "ring-face-b",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          layout.stack_length_mm,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * layout.ring_outer_radius_mm,
        description="output-side face of outer ring (z = stack_length)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "input-bore",
        placement=@common.Placement::identity(),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=2.0 * params.input_bore_radius_mm,
        depth_mm=layout.stack_length_mm,
        description="eccentric input shaft bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "output-face",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          layout.stack_length_mm,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * params.output_pin_circle_radius_mm,
        description="output carrier pin plane",
      ),
    )
  if y_up {
    comp = comp.rotate_x(-90.0)
  }
  Ok(comp)
}
