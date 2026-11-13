///|
/// herringbone_planetary_gearbox builds the fully parametric gearbox as one
/// component with named mate connectors. `num_elbows = 0` uses exact line/arc
/// extrusions (smooth straight gears); `num_elbows >= 1` uses the original
/// swept herringbone geometry, so dimensions and volumes match the original
/// generator.
pub fn herringbone_planetary_gearbox(
  params : HerringbonePlanetaryParams,
  y_up~ : Bool = false,
) -> Result[@common.Component, @common.SpecError] {
  let layout = herringbone_planetary_layout(params)
  let module_mm = layout.module_mm
  let length = layout.gear_length_mm
  let smooth = layout.num_elbows == 0
  let arc_placement = @common.Placement::rotation_x(-90.0)

  let sun_outline = hb_gear_outline(
    module_mm,
    layout.pressure_angle_deg,
    layout.sun.num_teeth,
    layout.resolution,
  )
  let sun_holes = hb_gear_holes(layout, layout.sun)
  let sun_max_rot = @math.tan(hb_deg2rad(layout.helix_angle_sun_deg)) *
    (length / 2.0) /
    layout.sun.outer_radius_mm
  let (sun_shape, sun_placement) = if smooth {
    (hb_arc_gear_shape(sun_outline, sun_holes, length), arc_placement)
  } else {
    (
      hb_swept_gear_shape(
        sun_outline,
        sun_holes,
        length,
        layout.num_elbows,
        sun_max_rot,
        layout.sun_direction,
        straight_holes=true,
        straight_outline=false,
      ),
      @common.Placement::identity(),
    )
  }

  let planet_outline = hb_gear_outline(
    module_mm,
    layout.pressure_angle_deg,
    layout.planet.num_teeth,
    layout.resolution,
  )
  let planet_holes = hb_gear_holes(layout, layout.planet)
  let planet_max_rot = @math.tan(hb_deg2rad(layout.helix_angle_deg)) *
    (length / 2.0) /
    layout.planet.outer_radius_mm

  let ring = hb_ring_geometry(layout)
  let outer_circle = hb_circle_outline(
    ring.outer_radius,
    layout.resolution * 8,
    true,
  )
  let inner_ccw = ring.inner.map(fn(pt) { hb_rotate_xz(pt, ring.phase) }).rev()
  let ring_max_rot = ring.ring_scale * ring.max_helix_mate
  let (ring_shape, ring_placement) = if smooth {
    (hb_arc_ring_shape(ring.outer_radius, inner_ccw, length), arc_placement)
  } else {
    (
      hb_swept_gear_shape(
        outer_circle,
        [inner_ccw],
        length,
        layout.num_elbows,
        ring_max_rot,
        layout.planet_direction,
      ),
      @common.Placement::identity(),
    )
  }

  let bore_diameter = if layout.hole_type == "None" {
    None
  } else {
    Some(2.0 * layout.hole_radius_mm)
  }
  let name = "herringbone-planetary-m\{@cad.fmt_double(module_mm, None)}-z\{layout.sun.num_teeth}"
  let features = @common.FeatureRecord::new(
    modeled=[
      "sun",
      "planets",
      "ring",
      if smooth {
        "straight-exact-extrusion"
      } else {
        "herringbone-twist"
      },
    ],
    approximated=[
      @common.Approximation::new(
        feature="tooth-outline",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=0.0,
        control="involute sampled at \{HB_INVOLUTE_POINTS} points per flank with resolution=\{layout.resolution} tip/root arcs",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="root-fillet",
        reason="the generator uses a theoretical involute root",
      ),
      @common.Omission::new(
        feature="tip-chamfer",
        reason="not modelled by this generator",
      ),
    ],
  )
  let mut component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Herringbone planetary gearbox m\{@cad.fmt_double(module_mm, None)} z\{layout.sun.num_teeth}/\{layout.planet.num_teeth}/\{layout.ring_teeth}",
      family="herringbone planetary gearbox",
      size="m\{@cad.fmt_double(module_mm, None)}-\{layout.sun.num_teeth}t-\{layout.planets.length()}p",
      length_mm=length,
      source="Parametric herringbone planetary gearbox; tooth counts, helix, tolerance, hole type and elbows are parameters.",
    ),
    description="Herringbone planetary gearbox: one sun, equally spaced planets, and an inward-facing ring gear. Straight exact extrusions when num_elbows is 0; swept herringbone otherwise.",
    features~,
  )
  component = component.add_layer(
    sun_shape,
    name="sun",
    color=@cad.Rgb::orange(),
    placement=sun_placement,
  )
  let mut planet_index = 0
  for p in layout.planets {
    let planet_shape = if smooth {
      hb_arc_gear_shape(planet_outline, planet_holes, length)
    } else {
      hb_swept_gear_shape(
        planet_outline,
        planet_holes,
        length,
        layout.num_elbows,
        planet_max_rot,
        layout.planet_direction,
        straight_holes=true,
        straight_outline=false,
      )
    }
    let at = @common.Placement::at(p.x, 0.0, p.z, ry=-p.phi_deg)
    let placement = if smooth {
      @common.Placement::compose(at, arc_placement)
    } else {
      at
    }
    component = component.add_layer(
      planet_shape,
      name="planet-\{planet_index + 1}",
      color=@cad.Rgb::blue(),
      placement~,
    )
    planet_index = planet_index + 1
  }
  component = component.add_layer(
    ring_shape,
    name="ring",
    color=@cad.Rgb::grey(),
    placement=ring_placement,
  )

  // Mate connectors, in the native +Y gear-axis frame. The final component
  // rotation (for the print-flat frame) transforms them too.
  component = hb_add_gear_connectors(
    component,
    "sun",
    @common.Placement::identity(),
    bore_diameter,
    2.0 * layout.sun.pitch_radius_mm,
    2.0 * layout.sun.outer_radius_mm,
    length,
  )
  planet_index = 0
  for p in layout.planets {
    let at = @common.Placement::at(p.x, 0.0, p.z, ry=-p.phi_deg)
    component = hb_add_gear_connectors(
      component,
      "planet-\{planet_index + 1}",
      at,
      bore_diameter,
      2.0 * layout.planet.pitch_radius_mm,
      2.0 * layout.planet.outer_radius_mm,
      length,
    )
    planet_index = planet_index + 1
  }
  component = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "ring-outer-seat",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=2.0 * ring.outer_radius,
        depth_mm=length,
        description="ring outside cylindrical seat",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "ring-pitch",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=2.0 * layout.ring.pitch_radius_mm,
        depth_mm=length,
        description="ring pitch-circle datum (the bore is toothed)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "ring-face-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * ring.outer_radius,
        description="ring face at y = 0",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "ring-face-b",
        placement=@common.Placement::translation(0.0, length, 0.0),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * ring.outer_radius,
        description="ring face at y = length",
      ),
    )
  if !y_up {
    component = component.rotate_x(90.0)
  }
  Ok(component)
}

///|
/// hb_add_gear_connectors adds the bore/pitch/face mate frames for one gear at
/// `placement` (native +Y axis).
fn hb_add_gear_connectors(
  component : @common.Component,
  prefix : String,
  placement : @common.Placement,
  bore_diameter : Double?,
  pitch_diameter : Double,
  outer_diameter : Double,
  length : Double,
) -> @common.Component {
  let mut out = component
  match bore_diameter {
    Some(d) =>
      out = out.with_connector_unchecked(
        @common.MateConnector::new(
          prefix + "-bore",
          placement~,
          axis=(0.0, 1.0, 0.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=d,
          depth_mm=length,
          description="central bore, entered from the y = 0 face",
        ),
      )
    None => ()
  }
  out = out.with_connector_unchecked(
    @common.MateConnector::new(
      prefix + "-pitch",
      placement~,
      axis=(0.0, 1.0, 0.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=pitch_diameter,
      depth_mm=length,
      description="pitch-circle datum",
    ),
  )
  out = out.with_connector_unchecked(
    @common.MateConnector::new(
      prefix + "-face-a",
      placement~,
      axis=(0.0, -1.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=outer_diameter,
      description="gear face at y = 0",
    ),
  )
  let top = @common.Placement::compose(
    placement,
    @common.Placement::translation(0.0, length, 0.0),
  )
  out.with_connector_unchecked(
    @common.MateConnector::new(
      prefix + "-face-b",
      placement=top,
      axis=(0.0, 1.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=outer_diameter,
      description="gear face at y = length",
    ),
  )
}
