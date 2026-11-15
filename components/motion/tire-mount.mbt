///|
/// TireMountSpec describes a wheel-side tire mounting flange.
///
/// The defaults are measured from the owner-authored
/// `components/testdata/golden/external/tire-mount.step` model. The frame is +X
/// along the wheel axis with the front face at `x = 0`: the part spans
/// `-total_width_mm .. 0`, the rear annulus spans `-total_width_mm ..
/// -plate_thickness_mm`, and the front plate spans `-plate_thickness_mm .. 0`.
/// The 6 narrow radial slots are 2 mm wide, matching the owner's tire ribs.
/// `slot_phase_deg` is expressed in the profile frame; the cutters are rotated
/// with `rotate_y(90deg)` before extrusion, which shifts the slots back by
/// 90 degrees, so the as-built slots land on 0/60/120/... degrees in the
/// output frame, matching the golden model and the tire's rib phase.
pub(all) struct TireMountSpec {
  outer_diameter_mm : Double
  front_inner_diameter_mm : Double
  hub_outer_diameter_mm : Double
  hub_bore_diameter_mm : Double
  plate_thickness_mm : Double
  ring_depth_mm : Double
  slot_width_mm : Double
  slot_count : Int32
  slot_phase_deg : Double
  bolt_hole_count : Int32
  bolt_hole_diameter_mm : Double
  bolt_hole_circle_diameter_mm : Double
  bolt_hole_phase_deg : Double
  front_offset_mm : Double
}

///|
/// tire_mount_spec returns the measured defaults from the owner-authored model.
pub fn tire_mount_spec() -> TireMountSpec {
  {
    outer_diameter_mm: 86.3,
    front_inner_diameter_mm: 51.85,
    hub_outer_diameter_mm: 25.4,
    hub_bore_diameter_mm: 12.7,
    plate_thickness_mm: 4.0,
    ring_depth_mm: 19.05,
    slot_width_mm: 2.0,
    slot_count: 6,
    slot_phase_deg: 90.0,
    bolt_hole_count: 3,
    bolt_hole_diameter_mm: 4.0,
    bolt_hole_circle_diameter_mm: 55.85,
    bolt_hole_phase_deg: 30.0,
    front_offset_mm: -5.0,
  }
}

///|
/// tire_mount_spec_valid validates a tire-mount specification.
pub fn tire_mount_spec_valid(
  spec : TireMountSpec,
) -> Result[Unit, @common.SpecError] {
  let positive : Array[(String, Double)] = [
    ("tire mount outer diameter", spec.outer_diameter_mm),
    ("tire mount front inner diameter", spec.front_inner_diameter_mm),
    ("tire mount hub outer diameter", spec.hub_outer_diameter_mm),
    ("tire mount hub bore diameter", spec.hub_bore_diameter_mm),
    ("tire mount plate thickness", spec.plate_thickness_mm),
    ("tire mount ring depth", spec.ring_depth_mm),
    ("tire mount slot width", spec.slot_width_mm),
    ("tire mount bolt hole diameter", spec.bolt_hole_diameter_mm),
    ("tire mount bolt hole circle", spec.bolt_hole_circle_diameter_mm),
  ]
  for entry in positive {
    let (name, value) = entry
    match @common.require_positive(name, value) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if !@common.is_finite(spec.front_offset_mm) {
    return Err(
      @common.InvalidDimension("tire mount front offset must be finite"),
    )
  }
  if spec.slot_count < 3 {
    return Err(
      @common.InvalidParameter("tire mount needs at least three slots"),
    )
  }
  if spec.bolt_hole_count < 1 {
    return Err(
      @common.InvalidParameter("tire mount needs at least one bolt hole"),
    )
  }
  if spec.front_inner_diameter_mm >= spec.outer_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "tire mount front opening must fit inside the outer diameter",
      ),
    )
  }
  if spec.hub_outer_diameter_mm >= spec.front_inner_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "tire mount hub must fit inside the front opening",
      ),
    )
  }
  if spec.hub_bore_diameter_mm >= spec.hub_outer_diameter_mm {
    return Err(
      @common.InvalidDimension("tire mount bore must be smaller than the hub"),
    )
  }
  let outer_radius = spec.outer_diameter_mm / 2.0
  let hub_radius = spec.hub_outer_diameter_mm / 2.0
  let slot_half_angle = @math.asin(spec.slot_width_mm / 2.0 / hub_radius) *
    180.0 /
    @math.PI
  if slot_half_angle >= 180.0 / spec.slot_count.to_double() {
    return Err(@common.InvalidParameter("tire mount slots would overlap"))
  }
  let bolt_reach = spec.bolt_hole_circle_diameter_mm / 2.0 +
    spec.bolt_hole_diameter_mm / 2.0
  if bolt_reach >= outer_radius ||
    spec.bolt_hole_circle_diameter_mm / 2.0 - spec.bolt_hole_diameter_mm / 2.0 <
    spec.front_inner_diameter_mm / 2.0 {
    return Err(
      @common.InvalidDimension(
        "tire mount bolt holes do not fit the front plate",
      ),
    )
  }
  Ok(())
}

///|
/// tire_mount builds a parameterized tire mounting flange.
///
/// The front plate is an annulus with three bolt holes; the rear ring is a
/// solid annulus around the hub tube; six 2 mm radial slots cut through both
/// the plate and the ring. The part is exported as an OCCT-evaluated solid by
/// the example so the slots and holes trim cleanly.
pub fn tire_mount(
  spec : TireMountSpec,
) -> Result[@common.Component, @common.SpecError] {
  match tire_mount_spec_valid(spec) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let outer_radius = spec.outer_diameter_mm / 2.0
  let total_width = spec.ring_depth_mm + spec.plate_thickness_mm
  let rear_start = -total_width
  // Start from a solid puck, then cut the annular gap between the central
  // post and the rear ring. Cutting from one solid keeps the evaluated result
  // manifold, unlike unioning several solids that touch on coincident faces.
  let body = @cad.RevolvedProfile::cylinder(spec.outer_diameter_mm, total_width)
    .as_shape()
    .with_name("tire-mount-body")
    .rotate_y(90.0)
    .translate(x=spec.front_offset_mm + rear_start)
  let slot_inner_radius = spec.hub_bore_diameter_mm / 2.0 + 0.1
  let cutters : Array[@cad.SceneNode] = [
    @cad.RevolvedProfile::tube(
      spec.hub_outer_diameter_mm,
      spec.hub_bore_diameter_mm,
      spec.ring_depth_mm,
    )
    .as_shape()
    .with_name("annular-gap-cutter")
    .rotate_y(90.0)
    .translate(x=spec.front_offset_mm + rear_start),
  ]
  for i in 0..<spec.slot_count {
    let angle = (
        spec.slot_phase_deg +
        360.0 * i.to_double() / spec.slot_count.to_double()
      ) *
      @math.PI /
      180.0
    let radial = (0.0, @math.cos(angle), @math.sin(angle))
    let tangent = (0.0, -@math.sin(angle), @math.cos(angle))
    let hub_point = (
      slot_inner_radius * radial.1 - spec.slot_width_mm / 2.0 * tangent.1,
      slot_inner_radius * radial.2 - spec.slot_width_mm / 2.0 * tangent.2,
    )
    let hub_point_plus = (
      slot_inner_radius * radial.1 + spec.slot_width_mm / 2.0 * tangent.1,
      slot_inner_radius * radial.2 + spec.slot_width_mm / 2.0 * tangent.2,
    )
    let outer_point = (
      outer_radius * radial.1 - spec.slot_width_mm / 2.0 * tangent.1,
      outer_radius * radial.2 - spec.slot_width_mm / 2.0 * tangent.2,
    )
    let outer_point_plus = (
      outer_radius * radial.1 + spec.slot_width_mm / 2.0 * tangent.1,
      outer_radius * radial.2 + spec.slot_width_mm / 2.0 * tangent.2,
    )
    let slot_loop : Array[@cad.ProfileSegment] = [
      @cad.SegmentLine(hub_point, outer_point),
      @cad.SegmentLine(outer_point, outer_point_plus),
      @cad.SegmentLine(outer_point_plus, hub_point_plus),
      @cad.SegmentLine(hub_point_plus, hub_point),
    ]
    let slot = @cad.ExtrudedArcProfile::new(slot_loop, spec.ring_depth_mm + 1.0)
    if !slot.validate() {
      return Err(
        @common.InvalidParameter(
          "tire mount slot cutter did not form a valid profile",
        ),
      )
    }
    cutters.push(
      slot
      .as_shape()
      .with_name("slot-cutter-\{i + 1}")
      .rotate_y(90.0)
      .translate(x=spec.front_offset_mm + rear_start - 1.0),
    )
  }
  let bolt_radius = spec.bolt_hole_circle_diameter_mm / 2.0
  for i in 0..<spec.bolt_hole_count {
    let angle = (
        spec.bolt_hole_phase_deg +
        360.0 * i.to_double() / spec.bolt_hole_count.to_double()
      ) *
      @math.PI /
      180.0
    cutters.push(
      @cad.RevolvedProfile::cylinder(
        spec.bolt_hole_diameter_mm,
        total_width + 2.0,
      )
      .as_shape()
      .with_name("bolt-hole-cutter")
      .rotate_y(90.0)
      .translate(
        x=spec.front_offset_mm + rear_start - 1.0,
        y=bolt_radius * @math.cos(angle),
        z=bolt_radius * @math.sin(angle),
      ),
    )
  }
  let mount = @cad.difference(body, cutters, name="tire-mount")
  let features = @common.FeatureRecord::new(
    modeled=[
      "front-plate", "rear-ring", "hub-post", "annular-gap", "radial-slots", "bolt-holes",
    ],
    omitted=[
      @common.Omission::new(
        feature="fasteners-and-tire",
        reason="the mating bolts and the tire are separate parts and are not modelled",
      ),
      @common.Omission::new(
        feature="surface-finish-and-material",
        reason="no finish, material, or strength rating is implied",
      ),
    ],
  )
  let mut mount_component = @common.Component::new(
    name="tire-mount-\{@cad.fmt_double(spec.outer_diameter_mm, None)}x\{@cad.fmt_double(total_width, None)}",
    metadata=@common.Metadata::new(
      designation="Tire mount Ø\{@cad.fmt_double(spec.outer_diameter_mm, None)} x \{@cad.fmt_double(total_width, None)}",
      standard="measured owner-authored tire-mount model",
      family="tire mounting flange",
      size="\{@cad.fmt_double(spec.outer_diameter_mm, None)}x\{@cad.fmt_double(total_width, None)}",
      length_mm=total_width,
      source="Defaults measured from components/testdata/golden/external/tire-mount.step (owner-authored; no third-party license). All dimensions are parameters.",
    ),
    description="Parameterized tire mounting flange with a front plate, rear ring, hub tube and bore, six 2 mm radial slots, and three bolt holes. Exported as an OCCT-evaluated solid.",
    features~,
  ).add_layer(
    mount.shape_intent(),
    name="tire-mount",
    color=@cad.Rgb::orange(),
    placement=@common.Placement::identity(),
  )
  // The mate sits on the post tip (the front face of the rear ring, i.e. the
  // inner face of the front plate). Snapping the tire's `hub-bore` mate onto
  // this mate seats the tire with its back plate flush against the rear face
  // and the post fully inside the bore, so no extra offset or twist is needed.
  mount_component = mount_component.with_connector_unchecked(
    @common.MateConnector::new(
      "hub-post",
      placement=@common.Placement::translation(
        spec.front_offset_mm - spec.plate_thickness_mm,
        0.0,
        0.0,
      ),
      axis=(1.0, 0.0, 0.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=spec.hub_bore_diameter_mm,
      depth_mm=spec.ring_depth_mm,
      description="tip of the solid central post; snap the tire's hub-bore mate here",
    ),
  )
  mount_component = mount_component.with_connector_unchecked(
    @common.MateConnector::new(
      "front-face",
      placement=@common.Placement::translation(spec.front_offset_mm, 0.0, 0.0),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=spec.outer_diameter_mm,
      description="external front mounting face",
    ),
  )
  mount_component = mount_component.with_connector_unchecked(
    @common.MateConnector::new(
      "rear-face",
      placement=@common.Placement::translation(
        spec.front_offset_mm + rear_start,
        0.0,
        0.0,
      ),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=spec.outer_diameter_mm,
      description="rear face",
    ),
  )
  for i in 0..<spec.bolt_hole_count {
    let angle = (
        spec.bolt_hole_phase_deg +
        360.0 * i.to_double() / spec.bolt_hole_count.to_double()
      ) *
      @math.PI /
      180.0
    mount_component = mount_component.with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-\{i + 1}",
        placement=@common.Placement::translation(
          spec.front_offset_mm,
          bolt_radius * @math.cos(angle),
          bolt_radius * @math.sin(angle),
        ),
        axis=(-1.0, 0.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        diameter_mm=spec.bolt_hole_diameter_mm,
        depth_mm=total_width,
        description="bolt hole on the external front face",
      ),
    )
  }
  Ok(mount_component)
}

///|
/// measured_tire_mount builds the owner-authored reference flange.
pub fn measured_tire_mount() -> Result[@common.Component, @common.SpecError] {
  tire_mount(tire_mount_spec())
}
