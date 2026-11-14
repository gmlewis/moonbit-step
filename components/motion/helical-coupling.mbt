///|
/// HelicalCouplingSize carries the measured geometry of a helical beam
/// coupling with clamp hubs.
///
/// The values are measured from the CC0 Innerscene 5-to-8 mm helical coupling.
/// The part is a sleeve with a stepped bore and a continuous helical slit cut
/// through the wall; each end carries a clamp slit and a socket-head clamp
/// screw.
pub(all) struct HelicalCouplingSize {
  outer_diameter_mm : Double
  length_mm : Double
  bore_small_mm : Double
  bore_large_mm : Double
  bore_step_z_mm : Double
  outer_chamfer_mm : Double
  slit_width_mm : Double
  slit_pitch_mm : Double
  slit_turns : Double
  slit_start_z_mm : Double
  slit_start_angle_deg : Double
  clamp_slit_width_mm : Double
  clamp_bottom_start_z_mm : Double
  clamp_bottom_end_z_mm : Double
  clamp_top_start_z_mm : Double
  clamp_top_end_z_mm : Double
  clamp_screw_x_mm : Double
  clamp_screw_bottom_z_mm : Double
  clamp_screw_top_z_mm : Double
  clamp_hole_diameter_mm : Double
  clamp_counterbore_diameter_mm : Double
  clamp_counterbore_depth_mm : Double
  clamp_screw_length_mm : Double
}

///|
/// helical_coupling_5_to_8 returns the measured 5-to-8 mm helical coupling
/// boundary.
pub fn helical_coupling_5_to_8() -> HelicalCouplingSize {
  {
    outer_diameter_mm: 25.0,
    length_mm: 30.0,
    bore_small_mm: 5.0,
    bore_large_mm: 8.0,
    bore_step_z_mm: 15.0,
    outer_chamfer_mm: 0.5,
    slit_width_mm: 0.7,
    slit_pitch_mm: 3.2,
    slit_turns: 3.0,
    slit_start_z_mm: 9.85,
    slit_start_angle_deg: 0.0,
    clamp_slit_width_mm: 0.8,
    clamp_bottom_start_z_mm: 0.0,
    clamp_bottom_end_z_mm: 8.0,
    clamp_top_start_z_mm: 22.0,
    clamp_top_end_z_mm: 30.0,
    clamp_screw_x_mm: 8.0,
    clamp_screw_bottom_z_mm: 4.0,
    clamp_screw_top_z_mm: 26.0,
    clamp_hole_diameter_mm: 3.2,
    clamp_counterbore_diameter_mm: 6.1,
    clamp_counterbore_depth_mm: 5.2,
    clamp_screw_length_mm: 12.0,
  }
}

///|
/// Margin added to a cutter so it clearly spans the material it trims.
const HELICAL_COUPLING_CUTTER_MARGIN_MM : Double = 1.0

///|
/// Cross-sections per turn used by the smooth ruled B-spline helicoid walls.
const HELICAL_COUPLING_SEGS_PER_TURN : Int32 = 60

///|
/// Axial inset of the clamp-screw head from the counterbore floor, enough to
/// keep the screw disjoint so the evaluated output stays a three-solid
/// assembly (as in the reference).
const HELICAL_COUPLING_SCREW_SEAT_INSET_MM : Double = 0.05

///|
/// helical_coupling builds a helical beam coupling with clamp hubs.
///
/// Frame: the axis is +Z, the coupling runs from `z = 0` to `length_mm`, and
/// the clamp slits and screws lie on the `x = +clamp_screw_x` side with the
/// slit in the `y = 0` plane. The bore is stepped: `bore_small_mm` from `z = 0`
/// to `bore_step_z_mm`, then `bore_large_mm` to the top. A continuous helical
/// slit of `slit_width_mm` is cut through the wall over `slit_turns` at
/// `slit_pitch_mm`, and each end has a `clamp_slit_width_mm` axial slit crossed
/// by a socket-head clamp screw.
///
/// The helical slit has smooth ruled B-spline walls sampled at 60
/// cross-sections per turn. Each clamp slit opens through its corresponding end
/// face, including the chamfer. The flat writer cannot trim any of the slits or
/// holes, so `Component::write_step_evaluated` (OCCT) is the accepted artifact.
/// The clamp-screw threads are declared by connectors, never modelled. No
/// torque, stiffness, or misalignment rating is implied.
pub fn helical_coupling(
  size~ : HelicalCouplingSize = helical_coupling_5_to_8(),
  color~ : @cad.Rgb = @cad.Rgb::new(0.56, 0.60, 0.64),
  screw_color~ : @cad.Rgb = @cad.Rgb::new(0.07, 0.085, 0.105),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive(
      "helical coupling outside diameter",
      size.outer_diameter_mm,
    ),
    @common.require_positive("helical coupling length", size.length_mm),
    @common.require_positive("helical coupling small bore", size.bore_small_mm),
    @common.require_positive("helical coupling large bore", size.bore_large_mm),
    @common.require_positive(
      "helical coupling bore step position",
      size.bore_step_z_mm,
    ),
    @common.require_non_negative(
      "helical coupling outer chamfer",
      size.outer_chamfer_mm,
    ),
    @common.require_positive("helical coupling slit width", size.slit_width_mm),
    @common.require_positive("helical coupling slit pitch", size.slit_pitch_mm),
    @common.require_positive("helical coupling slit turns", size.slit_turns),
    @common.require_non_negative(
      "helical coupling slit start",
      size.slit_start_z_mm,
    ),
    @common.require_positive(
      "helical coupling clamp slit width",
      size.clamp_slit_width_mm,
    ),
    @common.require_positive(
      "helical coupling clamp screw position",
      size.clamp_screw_x_mm,
    ),
    @common.require_positive(
      "helical coupling clamp hole",
      size.clamp_hole_diameter_mm,
    ),
    @common.require_positive(
      "helical coupling clamp counterbore",
      size.clamp_counterbore_diameter_mm,
    ),
    @common.require_positive(
      "helical coupling clamp counterbore depth",
      size.clamp_counterbore_depth_mm,
    ),
    @common.require_positive(
      "helical coupling clamp screw length",
      size.clamp_screw_length_mm,
    ),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let outer_r = size.outer_diameter_mm / 2.0
  let small_r = size.bore_small_mm / 2.0
  let large_r = size.bore_large_mm / 2.0
  if small_r >= large_r || large_r >= outer_r {
    return Err(
      @common.InvalidDimension(
        "helical coupling bores must increase from the small bore to the large bore, both inside the outside diameter",
      ),
    )
  }
  if size.bore_step_z_mm <= 0.0 || size.bore_step_z_mm >= size.length_mm {
    return Err(
      @common.InvalidDimension(
        "helical coupling bore step must lie inside the coupling length",
      ),
    )
  }
  if size.outer_chamfer_mm >= (outer_r - large_r) / 2.0 ||
    size.outer_chamfer_mm >= size.length_mm / 2.0 {
    return Err(
      @common.InvalidDimension(
        "helical coupling outer chamfer does not fit the wall",
      ),
    )
  }
  if size.slit_width_mm >= size.slit_pitch_mm {
    return Err(
      @common.InvalidDimension("helical coupling slit is wider than its pitch"),
    )
  }
  let slit_end = size.slit_start_z_mm + size.slit_pitch_mm * size.slit_turns
  if size.slit_start_z_mm <= 0.0 || slit_end >= size.length_mm {
    return Err(
      @common.InvalidDimension(
        "helical coupling slit must lie inside the coupling length",
      ),
    )
  }
  if size.bore_small_mm >= size.slit_start_z_mm {
    return Err(
      @common.InvalidDimension(
        "helical coupling slit starts inside the end hub",
      ),
    )
  }
  if !(size.clamp_bottom_start_z_mm < size.clamp_bottom_end_z_mm &&
    size.clamp_top_start_z_mm < size.clamp_top_end_z_mm &&
    size.clamp_bottom_end_z_mm <= size.clamp_top_start_z_mm &&
    size.clamp_top_end_z_mm <= size.length_mm &&
    size.clamp_bottom_start_z_mm >= 0.0) {
    return Err(
      @common.InvalidDimension(
        "helical coupling clamp slit ranges must be ordered and inside the length",
      ),
    )
  }
  if size.clamp_screw_x_mm <= large_r || size.clamp_screw_x_mm >= outer_r {
    return Err(
      @common.InvalidDimension(
        "helical coupling clamp screw must lie in the wall between the bore and the outside",
      ),
    )
  }
  let outer_at_screw = Double::sqrt(
    outer_r * outer_r - size.clamp_screw_x_mm * size.clamp_screw_x_mm,
  )
  if size.clamp_counterbore_diameter_mm >= 2.0 * outer_at_screw ||
    size.clamp_hole_diameter_mm >= size.clamp_counterbore_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "helical coupling clamp counterbore does not fit the wall",
      ),
    )
  }
  if size.clamp_counterbore_depth_mm >= outer_at_screw + outer_at_screw {
    return Err(
      @common.InvalidDimension("helical coupling clamp counterbore is too deep"),
    )
  }
  if !(size.clamp_screw_bottom_z_mm > size.clamp_bottom_start_z_mm &&
    size.clamp_screw_bottom_z_mm < size.clamp_bottom_end_z_mm &&
    size.clamp_screw_top_z_mm > size.clamp_top_start_z_mm &&
    size.clamp_screw_top_z_mm < size.clamp_top_end_z_mm) {
    return Err(
      @common.InvalidDimension(
        "helical coupling clamp screw must lie inside its clamp slit",
      ),
    )
  }
  let chamfer = size.outer_chamfer_mm
  let body_base = @cad.RevolvedProfile::polyline(
    [
      (small_r, 0.0),
      (outer_r - chamfer, 0.0),
      (outer_r, chamfer),
      (outer_r, size.length_mm - chamfer),
      (outer_r - chamfer, size.length_mm),
      (large_r, size.length_mm),
      (large_r, size.bore_step_z_mm),
      (small_r, size.bore_step_z_mm),
    ],
    closed=true,
  ).as_shape()
  // The helical slit cutter is a radial-by-axial slab swept along the helix.
  let path_radius = (small_r + outer_r) / 2.0
  let half_wall = (outer_r - small_r) / 2.0 + HELICAL_COUPLING_CUTTER_MARGIN_MM
  let path = @cad.helix_path(
    pos=(0.0, 0.0, size.slit_start_z_mm),
    size_per_turn=(path_radius, path_radius, size.slit_pitch_mm),
    num_turns=size.slit_turns,
    num_segs_per_turn=HELICAL_COUPLING_SEGS_PER_TURN,
    start_angle=size.slit_start_angle_deg,
    clockwise=false,
  )
  // Profile input coordinates map to local (X = radial, Y = axial):
  // local X = vx, local Y = -vz. The slab spans the wall radially and one slit
  // width axially (z = path_z .. path_z + slit_width).
  let cutter_profile = @cad.SweepProfile::new([
    (-half_wall, 0.0, 0.0),
    (-half_wall, 0.0, -size.slit_width_mm),
    (half_wall, 0.0, -size.slit_width_mm),
    (half_wall, 0.0, 0.0),
  ])
  let helical_slit = @cad.SweptProfile::new(
    path~,
    profile=cutter_profile,
    straight_outline=false,
    smooth_sides=true,
  ).with_name("helical-slit")
  let clamp_slit = fn(z_start : Double, z_end : Double) -> @cad.SceneNode {
    let cut_start = if z_start <= 0.0 {
      z_start - HELICAL_COUPLING_CUTTER_MARGIN_MM
    } else {
      z_start
    }
    let cut_end = if z_end >= size.length_mm {
      z_end + HELICAL_COUPLING_CUTTER_MARGIN_MM
    } else {
      z_end
    }
    @cad.Cuboid::new(
      outer_r + HELICAL_COUPLING_CUTTER_MARGIN_MM,
      size.clamp_slit_width_mm,
      cut_end - cut_start,
    )
    .with_name("clamp-slit")
    .translate(x=0.0, y=-size.clamp_slit_width_mm / 2.0, z=cut_start)
  }
  let clamp_slits = [
    clamp_slit(size.clamp_bottom_start_z_mm, size.clamp_bottom_end_z_mm),
    clamp_slit(size.clamp_top_start_z_mm, size.clamp_top_end_z_mm),
  ]
  let hole_cutters : Array[@cad.SceneNode] = []
  for z in [size.clamp_screw_bottom_z_mm, size.clamp_screw_top_z_mm] {
    // Through clearance hole along the y axis.
    hole_cutters.push(
      @cad.Cylinder::new(size.clamp_hole_diameter_mm, 4.0 * outer_r)
      .with_name("clamp-clearance-hole")
      .rotate_x(-90.0)
      .translate(x=size.clamp_screw_x_mm, y=-2.0 * outer_r, z~),
    )
    // Head counterbore from the +Y outside surface down to the floor.
    let floor_y = outer_at_screw - size.clamp_counterbore_depth_mm
    hole_cutters.push(
      @cad.Cylinder::new(size.clamp_counterbore_diameter_mm, 2.0 * outer_r)
      .with_name("clamp-counterbore")
      .rotate_x(-90.0)
      .translate(x=size.clamp_screw_x_mm, y=floor_y, z~),
    )
  }
  let cutters : Array[@cad.SceneNode] = [helical_slit]
  cutters.push_iter(clamp_slits.iter())
  cutters.push_iter(hole_cutters.iter())
  let body = @cad.difference(
    body_base.with_name("helical-coupling-body"),
    cutters,
    name="helical-coupling-body",
  )
  let features = @common.FeatureRecord::new(
    modeled=[
      "body", "stepped-bore", "outer-chamfers", "helical-slit", "clamp-slits", "clamp-clearance-holes",
      "clamp-counterbores", "clamp-screws",
    ],
    approximated=[
      @common.Approximation::new(
        feature="helical-slit",
        kind=@common.ApproximationKind::SweptSpline,
        deviation_mm=@common.chord_deviation(
          outer_r,
          HELICAL_COUPLING_SEGS_PER_TURN,
        ),
        control="smooth ruled B-spline walls sampled at \{HELICAL_COUPLING_SEGS_PER_TURN} cross-sections per turn",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="clamp-screw-threads",
        reason="the clamp threads are declared by the clamp-screw connectors; the modelled holes are clearance bores",
      ),
      @common.Omission::new(
        feature="torque-and-stiffness",
        reason="nominal geometry only; no torque, torsional stiffness, or misalignment rating is implied",
      ),
    ],
  )
  let mut component = @common.Component::new(
    name="helical-coupling-\{@cad.fmt_double(size.bore_small_mm, None)}x\{@cad.fmt_double(size.bore_large_mm, None)}",
    metadata=@common.Metadata::new(
      designation="Helical beam coupling \{@cad.fmt_double(size.bore_small_mm, None)} to \{@cad.fmt_double(size.bore_large_mm, None)} mm",
      family="helical coupling",
      size="\{@cad.fmt_double(size.bore_small_mm, None)}x\{@cad.fmt_double(size.bore_large_mm, None)}x\{@cad.fmt_double(size.outer_diameter_mm, None)}",
      length_mm=size.length_mm,
      source="Helical beam coupling measured from the CC0 Innerscene reference: sleeve with a stepped bore, a continuous helical slit, and two clamp hubs with socket-head clamp screws.",
    ),
    description="Helical beam coupling: a stepped-bore sleeve with a continuous smooth B-spline helical slit and two clamp hubs whose radial slits open through the end faces. The clamp threads are declared by connectors, not modelled. No torque, stiffness, or misalignment rating is implied.",
    features~,
  ).add_layer(body.shape_intent(), name="body", color~)
  for i in 0..<2 {
    let z = if i == 0 {
      size.clamp_screw_bottom_z_mm
    } else {
      size.clamp_screw_top_z_mm
    }
    let floor_y = outer_at_screw - size.clamp_counterbore_depth_mm
    let screw = match
      @fasteners.iso4762_screw(
        @standards.MetricSize::M3,
        size.clamp_screw_length_mm,
      ) {
      Ok(c) => c
      Err(e) => return Err(e)
    }
    let placed = screw
      .rotate_x(-90.0)
      .translate(
        x=size.clamp_screw_x_mm,
        y=floor_y + HELICAL_COUPLING_SCREW_SEAT_INSET_MM,
        z~,
      )
    component = pb_add_component_layers(
      component,
      placed,
      "clamp-screw-\{i + 1}",
      screw_color,
    )
  }
  Ok(with_helical_coupling_connectors(component, size, outer_at_screw))
}

///|
/// with_helical_coupling_connectors attaches the bores, the outside seat, both
/// end faces, and the two clamp-screw threads.
fn with_helical_coupling_connectors(
  component : @common.Component,
  size : HelicalCouplingSize,
  outer_at_screw : Double,
) -> @common.Component {
  let floor_y = outer_at_screw - size.clamp_counterbore_depth_mm
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore-small",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=size.bore_small_mm,
        depth_mm=size.bore_step_z_mm,
        description="small shaft bore, entered from the z = 0 end",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore-large",
        placement=@common.Placement::translation(0.0, 0.0, size.length_mm),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=size.bore_large_mm,
        depth_mm=size.length_mm - size.bore_step_z_mm,
        description="large shaft bore, entered from the z = length end",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "outer-seat",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=size.outer_diameter_mm,
        depth_mm=size.length_mm,
        description="outside cylindrical surface of the sleeve",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-small",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=size.outer_diameter_mm,
        description="negative-Z end face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-large",
        placement=@common.Placement::translation(0.0, 0.0, size.length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=size.outer_diameter_mm,
        description="positive-Z end face",
      ),
    )
  for i in 0..<2 {
    let z = if i == 0 {
      size.clamp_screw_bottom_z_mm
    } else {
      size.clamp_screw_top_z_mm
    }
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "clamp-screw-\{i + 1}",
        placement=@common.Placement::translation(
          size.clamp_screw_x_mm,
          floor_y,
          z,
        ),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Female,
        diameter_mm=3.0,
        depth_mm=size.clamp_screw_length_mm,
        description="M3 clamp-screw thread across the clamp slit; the modelled holes are a \{@cad.fmt_double(size.clamp_hole_diameter_mm, None)} mm clearance bore and a \{@cad.fmt_double(size.clamp_counterbore_diameter_mm, None)} mm head counterbore",
      ),
    )
  }
  out
}
