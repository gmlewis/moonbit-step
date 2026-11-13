///|
/// Default rivet head diameter as a multiple of the shank diameter.
const RIVET_HEAD_DIAMETER_RATIO : Double = 1.8

///|
/// Default rivet head height as a multiple of the shank diameter.
const RIVET_HEAD_HEIGHT_RATIO : Double = 0.35

///|
/// solid_rivet builds a generic solid rivet: a flat cylindrical head plus a
/// straight shank.
///
/// Frame: the head's bearing face is at `z = 0` (outward normal -Z), the head
/// runs from `z = 0` to `z = head_height_mm`, and the shank runs from the head
/// underside to `z = length_mm`. The rivet is centred on the Z axis.
///
/// This is a generic parametric form, not a standard part. No standard table,
/// grip range, head radius, or tail-forming allowance is claimed, and the tail
/// is left as a square shank end rather than a formed upset.
pub fn solid_rivet(
  shank_diameter_mm : Double,
  length_mm : Double,
  head_diameter_mm~ : Double = 0.0,
  head_height_mm~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::orange(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("rivet shank diameter", shank_diameter_mm),
    @common.require_positive("rivet length", length_mm),
    @common.require_non_negative("rivet head diameter", head_diameter_mm),
    @common.require_non_negative("rivet head height", head_height_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let head_diameter = if head_diameter_mm > 0.0 {
    head_diameter_mm
  } else {
    RIVET_HEAD_DIAMETER_RATIO * shank_diameter_mm
  }
  let head_height = if head_height_mm > 0.0 {
    head_height_mm
  } else {
    RIVET_HEAD_HEIGHT_RATIO * shank_diameter_mm
  }
  if head_diameter <= shank_diameter_mm {
    return Err(
      @common.InvalidParameter(
        "rivet head diameter must be larger than its shank",
      ),
    )
  }
  if head_height >= length_mm {
    return Err(
      @common.InvalidParameter(
        "rivet head height must be smaller than its length",
      ),
    )
  }
  let head_r = head_diameter / 2.0
  let shank_r = shank_diameter_mm / 2.0
  let body = @cad.RevolvedProfile::polyline([
    (0.0, 0.0),
    (head_r, 0.0),
    (head_r, head_height),
    (shank_r, head_height),
    (shank_r, length_mm),
    (0.0, length_mm),
  ])
  let features = @common.FeatureRecord::new(
    modeled=["head", "shank", "head-seat", "tail-face"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="standard-table-and-grip-range",
        reason="the rivet is sized by explicit parameters; no standard table or grip range is claimed",
      ),
      @common.Omission::new(
        feature="formed-tail",
        reason="the rivet is modelled before setting; the upset tail and its allowance are not modelled",
      ),
      @common.Omission::new(
        feature="head-radius",
        reason="the head is a flat cylinder; a domed or countersunk head is not modelled",
      ),
    ],
  )
  let component = @common.Component::new(
    name="solid-rivet-\{@cad.fmt_double(shank_diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}",
    metadata=@common.Metadata::new(
      designation="Solid rivet \{@cad.fmt_double(shank_diameter_mm, None)} x \{@cad.fmt_double(length_mm, None)} (generic)",
      family="solid rivet (generic)",
      size="\{@cad.fmt_double(shank_diameter_mm, None)}",
      length_mm~,
      source="Generic parametric solid rivet: cylindrical head and straight shank. No standard table, grip range, or formed-tail geometry is implied.",
    ),
    description="Generic solid rivet: one analytic solid of revolution, a flat cylindrical head over a straight shank. No standard table, grip range, head radius, or formed tail is modelled.",
    features~,
  ).add_layer(body.as_shape(), name="body", color~)
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "head-seat",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=head_diameter,
        description="head bearing face; outward normal is -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "head-underside",
        placement=@common.Placement::translation(0.0, 0.0, head_height),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=head_diameter,
        description="annular head underside that bears on the workpiece",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "shank",
        placement=@common.Placement::translation(0.0, 0.0, head_height),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=shank_diameter_mm,
        depth_mm=length_mm - head_height,
        description="shank that passes through the work; extends to the tail face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "tail-face",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=shank_diameter_mm,
        description="square shank end before setting",
      ),
    ),
  )
}
