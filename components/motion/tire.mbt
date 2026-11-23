///|
/// TireSpec describes a simple wheel: an outer tire ring, a hub tube, a
/// five-or-more-spoke rib set, and an inset back plate.
///
/// The defaults are measured from the owner-authored
/// `components/testdata/golden/external/tire.step` model. The frame is +X along the
/// wheel axis with the outer face at `x = 0`: the tire spans
/// `-tire_width_mm .. 0`, the hub spans `-hub_length_mm .. 0`, and the inset
/// plate back face is at `-(hub_inset_mm + inset_thickness_mm)`.
///
/// All dimensions are millimetres. Override any value to match a measured
/// tire. This is a mechanical envelope: no rubber compound, tread pattern,
/// load rating, or speed rating is implied.
pub(all) struct TireSpec {
  tire_outer_diameter_mm : Double
  tire_inner_diameter_mm : Double
  tire_width_mm : Double
  hub_outer_diameter_mm : Double
  hub_bore_diameter_mm : Double
  hub_length_mm : Double
  hub_inset_mm : Double
  inset_thickness_mm : Double
  rib_thickness_mm : Double
  rib_count : Int32
  rib_phase_deg : Double
}

///|
/// tire_spec returns the measured defaults from the owner-authored model.
pub fn tire_spec() -> TireSpec {
  {
    tire_outer_diameter_mm: 177.8,
    tire_inner_diameter_mm: 127.0,
    tire_width_mm: 38.1,
    hub_outer_diameter_mm: 25.4,
    hub_bore_diameter_mm: 12.7,
    hub_length_mm: 34.925,
    hub_inset_mm: 19.05,
    inset_thickness_mm: 2.0,
    rib_thickness_mm: 2.0,
    rib_count: 6,
    rib_phase_deg: 0.0,
  }
}

///|
/// tire_spec_valid validates a tire envelope specification.
pub fn tire_spec_valid(spec : TireSpec) -> Result[Unit, @common.SpecError] {
  let positive : Array[(String, Double)] = [
    ("tire outer diameter", spec.tire_outer_diameter_mm),
    ("tire inner diameter", spec.tire_inner_diameter_mm),
    ("tire width", spec.tire_width_mm),
    ("tire hub outer diameter", spec.hub_outer_diameter_mm),
    ("tire hub bore diameter", spec.hub_bore_diameter_mm),
    ("tire hub length", spec.hub_length_mm),
    ("tire hub inset", spec.hub_inset_mm),
    ("tire inset thickness", spec.inset_thickness_mm),
    ("tire rib thickness", spec.rib_thickness_mm),
  ]
  for entry in positive {
    let (name, value) = entry
    match @common.require_positive(name, value) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if spec.rib_count < 3 {
    return Err(@common.InvalidParameter("tire needs at least three ribs"))
  }
  let tire_outer = spec.tire_outer_diameter_mm / 2.0
  let tire_inner = spec.tire_inner_diameter_mm / 2.0
  let hub_outer = spec.hub_outer_diameter_mm / 2.0
  let hub_bore = spec.hub_bore_diameter_mm / 2.0
  if spec.tire_inner_diameter_mm >= spec.tire_outer_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "tire inner diameter must be smaller than the outer diameter",
      ),
    )
  }
  if spec.hub_outer_diameter_mm >= spec.tire_inner_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "tire hub must fit inside the tire inner diameter",
      ),
    )
  }
  if spec.hub_bore_diameter_mm >= spec.hub_outer_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "tire hub bore must be smaller than the hub outer diameter",
      ),
    )
  }
  if spec.hub_inset_mm > spec.tire_width_mm ||
    spec.hub_inset_mm + spec.inset_thickness_mm > spec.tire_width_mm {
    return Err(
      @common.InvalidDimension(
        "tire hub inset and inset plate must fit inside the tire width",
      ),
    )
  }
  let rib_sector_half_mm = hub_outer *
    @math.sin(@math.PI / spec.rib_count.to_double())
  if spec.rib_thickness_mm >= 2.0 * rib_sector_half_mm {
    return Err(@common.InvalidParameter("tire ribs would overlap at the hub"))
  }
  if tire_inner <= hub_outer || hub_bore <= 0.0 || tire_outer <= tire_inner {
    return Err(@common.InvalidDimension("tire radii are inconsistent"))
  }
  Ok(())
}

///|
/// tire_circle_loop returns a counter-clockwise circle as four minor arcs.
fn tire_circle_loop(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  @common.circle_loop(cx, cy, radius)
}

///|
/// tire_axis_placement places a Z-revolved or Z-extruded body on the +X axis.
fn tire_axis_placement(x_mm : Double) -> @common.Placement {
  @common.Placement::compose(
    @common.Placement::translation(x_mm, 0.0, 0.0),
    @common.Placement::rotation_y(90.0),
  )
}

///|
/// tire builds a parameterized wheel envelope.
///
/// The tire is a revolved ring, the hub a revolved tube, the inset plate an
/// extruded annulus with a bore, and the ribs are `rib_count` straight
/// rectangular spokes of `rib_thickness_mm` that run from the hub outer
/// surface to the tire inner surface over the `hub_inset_mm` axial depth.
/// The measured defaults reproduce the owner-authored model within its
/// measurement tolerance.
pub fn tire(spec : TireSpec) -> Result[@common.Component, @common.SpecError] {
  match tire_spec_valid(spec) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let tire_inner = spec.tire_inner_diameter_mm / 2.0
  let hub_outer = spec.hub_outer_diameter_mm / 2.0
  let rib_length = tire_inner - hub_outer
  let ring = @cad.RevolvedProfile::tube(
    spec.tire_outer_diameter_mm,
    spec.tire_inner_diameter_mm,
    spec.tire_width_mm,
  ).as_shape()
  let hub = @cad.RevolvedProfile::tube(
    spec.hub_outer_diameter_mm,
    spec.hub_bore_diameter_mm,
    spec.hub_length_mm,
  ).as_shape()
  let plate = @cad.ExtrudedArcProfile::new(
    tire_circle_loop(0.0, 0.0, tire_inner),
    spec.inset_thickness_mm,
    holes=[tire_circle_loop(0.0, 0.0, hub_outer)],
  )
  if !plate.validate() {
    return Err(
      @common.InvalidParameter("tire inset plate did not form a valid profile"),
    )
  }
  let rib = @cad.Cuboid::new(
    rib_length,
    spec.rib_thickness_mm,
    spec.hub_inset_mm,
  )
  // The owner-authored model closes the bore at the back plate with a solid
  // plug of the bore diameter spanning the plate thickness.
  let bore_plug = @cad.RevolvedProfile::cylinder(
    spec.hub_bore_diameter_mm,
    spec.inset_thickness_mm,
  ).as_shape()
  let layers : Array[@common.ComponentLayer] = [
    {
      shape: ring,
      name: "tire-ring",
      color: @cad.Rgb::black(),
      placement: tire_axis_placement(-spec.tire_width_mm),
    },
    {
      shape: hub,
      name: "hub",
      color: @cad.Rgb::grey(),
      placement: tire_axis_placement(-spec.hub_length_mm),
    },
    {
      shape: plate.as_shape(),
      name: "inset-plate",
      color: @cad.Rgb::grey(),
      placement: tire_axis_placement(
        -(spec.hub_inset_mm + spec.inset_thickness_mm),
      ),
    },
    {
      shape: bore_plug,
      name: "bore-plug",
      color: @cad.Rgb::grey(),
      placement: tire_axis_placement(
        -(spec.hub_inset_mm + spec.inset_thickness_mm),
      ),
    },
  ]
  for i in 0..<spec.rib_count {
    let angle = (
        spec.rib_phase_deg + 360.0 * i.to_double() / spec.rib_count.to_double()
      ) *
      @math.PI /
      180.0
    let radial = (0.0, @math.cos(angle), @math.sin(angle))
    let tangent = (0.0, -@math.sin(angle), @math.cos(angle))
    // Cuboid corners start at its local origin, so place that corner at the
    // hub surface, one half-thickness to one side, and the inset back face.
    layers.push({
      shape: rib,
      name: "rib-\{i + 1}",
      color: @cad.Rgb::grey(),
      placement: {
        rot: @cad.Matrix3x3::{
          m00: radial.0,
          m01: tangent.0,
          m02: 1.0,
          m10: radial.1,
          m11: tangent.1,
          m12: 0.0,
          m20: radial.2,
          m21: tangent.2,
          m22: 0.0,
        },
        trans: (
          -spec.hub_inset_mm,
          hub_outer * radial.1 - spec.rib_thickness_mm / 2.0 * tangent.1,
          hub_outer * radial.2 - spec.rib_thickness_mm / 2.0 * tangent.2,
        ),
      },
    })
  }
  let features = @common.FeatureRecord::new(
    modeled=[
      "tire-ring", "tread", "sidewalls", "hub-tube", "hub-bore", "inset-plate", "ribs",
      "bore-plug", "windows",
    ],
    omitted=[
      @common.Omission::new(
        feature="tread-pattern",
        reason="the tire is a smooth mechanical ring; no tread blocks or grooves are modelled",
      ),
      @common.Omission::new(
        feature="rubber-compound-and-carcass",
        reason="material, belts, bead wires, and sidewall markings are not modelled",
      ),
      @common.Omission::new(
        feature="valve-and-balance-features",
        reason="no valve stem, balance weights, or mounting hardware are modelled",
      ),
      @common.Omission::new(
        feature="load-and-speed-ratings",
        reason="no load, speed, inflation, or safety rating is implied",
      ),
    ],
  )
  let mut wheel = @common.Component::new(
    name="tire-\{@cad.fmt_double(spec.tire_outer_diameter_mm, None)}x\{@cad.fmt_double(spec.tire_width_mm, None)}",
    metadata=@common.Metadata::new(
      designation="Tire Ø\{@cad.fmt_double(spec.tire_outer_diameter_mm, None)} x \{@cad.fmt_double(spec.tire_width_mm, None)}, hub Ø\{@cad.fmt_double(spec.hub_outer_diameter_mm, None)} x \{@cad.fmt_double(spec.hub_length_mm, None)}",
      standard="measured owner-authored tire model",
      family="wheel and tire envelope",
      size="\{@cad.fmt_double(spec.tire_outer_diameter_mm, None)}x\{@cad.fmt_double(spec.tire_width_mm, None)}",
      length_mm=spec.tire_width_mm,
      source="Defaults measured from components/testdata/golden/external/tire.step (owner-authored; no third-party license). All dimensions are parameters.",
    ),
    description="Parameterized wheel envelope with a smooth tire ring, hub tube and bore, inset back plate, and straight radial ribs. No tread pattern, rubber compound, or load/speed rating is implied.",
    features~,
  ).add_layers(layers)
  wheel = wheel.with_connector_unchecked(
    @common.MateConnector::new(
      "hub-bore",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(1.0, 0.0, 0.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=spec.hub_bore_diameter_mm,
      depth_mm=spec.hub_length_mm,
      description="mouth of the through hub bore; snap onto the tire mount's hub-post mate to seat the wheel",
    ),
  )
  wheel = wheel.with_connector_unchecked(
    @common.MateConnector::new(
      "mount-seat",
      placement=@common.Placement::translation(-spec.hub_inset_mm, 0.0, 0.0),
      axis=(1.0, 0.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=spec.hub_outer_diameter_mm,
      description="inner face of the back plate; seats against the tire mount's rear-face mate",
    ),
  )
  wheel = wheel.with_connector_unchecked(
    @common.MateConnector::new(
      "hub-face",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=spec.hub_outer_diameter_mm,
      description="hub front face, flush with the tire outer face",
    ),
  )
  wheel = wheel.with_connector_unchecked(
    @common.MateConnector::new(
      "hub-rear",
      placement=@common.Placement::translation(-spec.hub_length_mm, 0.0, 0.0),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=spec.hub_outer_diameter_mm,
      description="hub rear face",
    ),
  )
  wheel = wheel.with_connector_unchecked(
    @common.MateConnector::new(
      "tread",
      placement=@common.Placement::translation(
        -spec.tire_width_mm / 2.0,
        0.0,
        0.0,
      ),
      axis=(0.0, 1.0, 0.0),
      kind=@common.MateKind::Datum,
      diameter_mm=spec.tire_outer_diameter_mm,
      depth_mm=spec.tire_width_mm,
      description="tire tread datum (no contact claim)",
    ),
  )
  Ok(wheel)
}

///|
/// measured_tire builds the owner-authored reference wheel.
pub fn measured_tire() -> Result[@common.Component, @common.SpecError] {
  tire(tire_spec())
}
