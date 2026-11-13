///|
/// GT2 timing-belt pitch in millimetres (2 mm).
const GT2_PITCH_MM : Double = 2.0

///|
/// GT2 pitch-line offset from the tooth tip in millimetres.
const GT2_PITCH_LINE_OFFSET_MM : Double = 0.254

///|
/// Approximate GT2 tooth depth in millimetres. The profile below is an
/// engineering approximation built from the published pitch, offset, and tooth
/// width; it is not a licensed exact tooth form.
const GT2_TOOTH_DEPTH_MM : Double = 0.76

///|
/// Approximate GT2 tooth width at the pitch line in millimetres.
const GT2_TOOTH_WIDTH_MM : Double = 1.49

///|
/// Default flange diameter allowance beyond the outside diameter, millimetres.
const GT2_FLANGE_ALLOWANCE_MM : Double = 2.0

///|
/// GT2Geometry records the pitch, outside, and root diameters for a tooth count.
pub(all) struct GT2Geometry {
  teeth : Int32
  pitch_diameter_mm : Double
  outside_diameter_mm : Double
  root_diameter_mm : Double
}

///|
/// gt2_geometry returns the GT2 pitch, outside, and root diameters.
///
/// Pitch diameter is `teeth * 2 / pi`. The outside diameter subtracts twice the
/// 0.254 mm pitch-line offset, and the root diameter subtracts twice the 0.76 mm
/// approximate tooth depth. The tooth form itself is an approximation.
pub fn gt2_geometry(teeth : Int32) -> Result[GT2Geometry, @common.SpecError] {
  if teeth < 10 {
    return Err(@common.InvalidParameter("GT2 pulley needs at least 10 teeth"))
  }
  let pitch_diameter = teeth.to_double() * GT2_PITCH_MM / @math.PI
  let outside_diameter = pitch_diameter - 2.0 * GT2_PITCH_LINE_OFFSET_MM
  let root_diameter = outside_diameter - 2.0 * GT2_TOOTH_DEPTH_MM
  if root_diameter <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "GT2 tooth count gives a non-positive root diameter",
      ),
    )
  }
  Ok({
    teeth,
    pitch_diameter_mm: pitch_diameter,
    outside_diameter_mm: outside_diameter,
    root_diameter_mm: root_diameter,
  })
}

///|
/// push_arc appends points on a circular arc, excluding the start angle when
/// `include_start` is false.
fn push_gt2_arc(
  points : Array[@cad.Vec2],
  radius : Double,
  start : Double,
  finish : Double,
  segments : Int32,
  include_start~ : Bool,
) -> Unit {
  let count = if segments < 1 { 1 } else { segments }
  for k in 0..<=count {
    if k == 0 && !include_start {
      continue
    }
    let t = k.to_double() / count.to_double()
    let angle = start + (finish - start) * t
    points.push((radius * @math.cos(angle), radius * @math.sin(angle)))
  }
}

///|
/// gt2_tooth_outline builds a counter-clockwise approximated GT2 tooth profile.
///
/// Each tooth is a trapezoid with sampled root and tip arcs. The profile is a
/// polygon: it is an engineering approximation for printed prototypes, not an
/// exact licensed tooth form.
fn gt2_tooth_outline(
  geom : GT2Geometry,
  arc_segments~ : Int32 = 4,
) -> Array[@cad.Vec2] {
  let pitch_radius = geom.pitch_diameter_mm / 2.0
  let tip_radius = geom.outside_diameter_mm / 2.0
  let root_radius = geom.root_diameter_mm / 2.0
  let step = 2.0 * @math.PI / geom.teeth.to_double()
  let root_half_raw = GT2_TOOTH_WIDTH_MM * 0.9 / (2.0 * pitch_radius)
  let tip_half_raw = GT2_TOOTH_WIDTH_MM * 0.6 / (2.0 * pitch_radius)
  let max_half = step * 0.45
  let root_half = if root_half_raw < max_half {
    root_half_raw
  } else {
    max_half
  }
  let tip_half = if tip_half_raw < root_half { tip_half_raw } else { root_half }
  let points : Array[@cad.Vec2] = []
  for i in 0..<geom.teeth {
    let center = i.to_double() * step
    let start = center - step / 2.0
    let end = center + step / 2.0
    push_gt2_arc(
      points,
      root_radius,
      start,
      center - root_half,
      arc_segments,
      include_start=true,
    )
    points.push(
      (
        tip_radius * @math.cos(center - tip_half),
        tip_radius * @math.sin(center - tip_half),
      ),
    )
    push_gt2_arc(
      points,
      tip_radius,
      center - tip_half,
      center + tip_half,
      arc_segments,
      include_start=false,
    )
    points.push(
      (
        root_radius * @math.cos(center + root_half),
        root_radius * @math.sin(center + root_half),
      ),
    )
    push_gt2_arc(
      points,
      root_radius,
      center + root_half,
      end,
      arc_segments,
      include_start=false,
    )
  }
  points
}

///|
/// gt2_pulley builds an approximated GT2 timing pulley with a central bore and
/// optional end flanges.
///
/// The pulley axis is +Z, the belt runs over `z = 0 .. belt_width_mm`, and the
/// bore is coaxial. The tooth outline is a polygon approximation from the
/// published 2 mm pitch, 0.254 mm pitch-line offset, 0.76 mm depth, and 1.49 mm
/// width; it is not presented as an exact licensed GT2 profile.
///
/// Flanges are separate annular layers at the two ends. They abut the toothed
/// body rather than being trimmed into it.
pub fn gt2_pulley(
  teeth : Int32,
  belt_width_mm : Double,
  bore_diameter_mm : Double,
  flanges~ : Bool = true,
  flange_thickness_mm~ : Double = 1.0,
  flange_diameter_mm? : Double,
  detail~ : @common.DetailLevel = @common.DetailLevel::Detailed,
  color~ : @cad.Rgb = @cad.Rgb::orange(),
) -> Result[@common.Component, @common.SpecError] {
  let geom = match gt2_geometry(teeth) {
    Ok(g) => g
    Err(e) => return Err(e)
  }
  match @common.require_positive("GT2 belt width", belt_width_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("GT2 bore diameter", bore_diameter_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if bore_diameter_mm >= geom.root_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "GT2 bore must be smaller than the root diameter",
      ),
    )
  }
  let use_flanges = flanges && belt_width_mm > 3.0 * flange_thickness_mm
  let flange_t = if use_flanges { flange_thickness_mm } else { 0.0 }
  if use_flanges {
    match
      @common.require_positive("GT2 flange thickness", flange_thickness_mm) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let default_flange_d = geom.outside_diameter_mm + GT2_FLANGE_ALLOWANCE_MM
  let flange_d = match flange_diameter_mm {
    Some(d) => d
    None => default_flange_d
  }
  if use_flanges && flange_d < geom.outside_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "GT2 flange diameter must be at least the outside diameter",
      ),
    )
  }
  let _ = detail
  let body_height = belt_width_mm - 2.0 * flange_t
  let outline = gt2_tooth_outline(geom)
  let body = @cad.ExtrudedProfile::new(
    outline,
    body_height,
    round_bore=((0.0, 0.0), bore_diameter_mm),
  )
  let name = "GT2-\{teeth}T-\{@cad.fmt_double(belt_width_mm, None)}-b\{@cad.fmt_double(bore_diameter_mm, None)}"
  let mut component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="GT2 pulley \{teeth}T, belt width \{@cad.fmt_double(belt_width_mm, None)} mm",
      standard="GT2 2 mm pitch geometry (approximated tooth form)",
      family="timing pulley",
      size="\{teeth}T",
      length_mm=belt_width_mm,
      material="printed or machined (label only; no strength claim)",
      source="Pitch 2.0 mm, pitch-line offset 0.254 mm, tooth depth about 0.76 mm, and tooth width about 1.49 mm. Tooth flanks are an engineering approximation, not a licensed exact GT2 profile.",
    ),
    description="Approximated GT2 timing pulley with a central bore and optional end flanges. The tooth form is a trapezoidal polygon built from published pitch/offset/depth/width values; it is not an exact licensed profile and no load rating is implied.",
    features=@common.FeatureRecord::new(
      modeled=["body", "central-bore", "approximate-gt2-teeth", "end-flanges"],
      approximated=[
        @common.Approximation::new(
          feature="gt2-tooth-form",
          kind=@common.ApproximationKind::EngineeringDefault,
          deviation_mm=0.0,
          control="trapezoidal polygon from 2.0 mm pitch, 0.254 mm offset, 0.76 mm depth, 1.49 mm width",
        ),
        @common.Approximation::new(
          feature="flange-diameter",
          kind=@common.ApproximationKind::EngineeringDefault,
          deviation_mm=0.0,
          control="default outside diameter + 2.0 mm unless supplied",
        ),
      ],
      omitted=[
        @common.Omission::new(
          feature="exact-licensed-gt2-profile",
          reason="no licensed exact tooth data is encoded; treat this as a prototype approximation",
        ),
        @common.Omission::new(
          feature="set-screws-and-clamp",
          reason="hub clamping is not modelled",
        ),
        @common.Omission::new(
          feature="load-rating",
          reason="geometry only; torque and belt-life ratings require testing",
        ),
      ],
    ),
  )
  if body_height > 0.0 {
    component = component.add_layer(
      body,
      name="toothed-body",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, flange_t),
    )
  }
  if use_flanges {
    let flange = @cad.RevolvedProfile::tube(
      flange_d, bore_diameter_mm, flange_t,
    )
    component = component
      .add_layer(flange.as_shape(), name="flange-bottom", color~)
      .add_layer(
        flange.as_shape(),
        name="flange-top",
        color~,
        placement=@common.Placement::translation(
          0.0,
          0.0,
          belt_width_mm - flange_t,
        ),
      )
  }
  let outer_d = if use_flanges { flange_d } else { geom.outside_diameter_mm }
  Ok(
    with_bore_and_faces(component, bore_diameter_mm, outer_d, belt_width_mm).with_connector_unchecked(
      @common.MateConnector::new(
        "pitch-datum",
        placement=@common.Placement::translation(0.0, 0.0, belt_width_mm / 2.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=geom.pitch_diameter_mm,
        depth_mm=belt_width_mm,
        description="pitch-circle datum at the belt mid-plane",
      ),
    ),
  )
}
