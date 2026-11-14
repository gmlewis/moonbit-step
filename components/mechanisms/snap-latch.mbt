///|
/// snap_latch builds a cantilever snap-fit latch with a ramp hook.
///
/// Frame: the beam axis is +X, its thickness is along Y, and its width is along
/// Z. The beam runs from `x = 0` to `x = beam_length` with its root face at
/// `x = 0`. The underside carries a ramp of `ramp_length` that falls to an
/// engagement depth `hook_depth` below the beam bottom at the free end. The
/// section is extruded through `beam_width`.
///
/// This is a printable-feature envelope. No engagement force, strain, fatigue,
/// or retention strength is claimed; those require testing.
pub fn snap_latch(
  beam_length_mm : Double,
  beam_thickness_mm : Double,
  beam_width_mm : Double,
  hook_depth_mm : Double,
  ramp_length_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::green(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("snap latch beam length", beam_length_mm),
      ("snap latch beam thickness", beam_thickness_mm),
      ("snap latch beam width", beam_width_mm),
      ("snap latch hook depth", hook_depth_mm),
      ("snap latch ramp length", ramp_length_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if ramp_length_mm >= beam_length_mm {
    return Err(
      @common.InvalidDimension("snap latch ramp must be shorter than the beam"),
    )
  }
  let profile : Array[(Double, Double)] = [
    (0.0, 0.0),
    (beam_length_mm - ramp_length_mm, 0.0),
    (beam_length_mm, -hook_depth_mm),
    (beam_length_mm, beam_thickness_mm),
    (0.0, beam_thickness_mm),
  ]
  if @cad.polygon_area_2d(profile) <= 0.0 {
    return Err(
      @common.InvalidParameter("snap latch profile is not counter-clockwise"),
    )
  }
  let body = @cad.ExtrudedProfile::new(profile, beam_width_mm)
  let features = @common.FeatureRecord::new(
    modeled=["cantilever-beam", "ramp-hook"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="engagement-force-and-strain",
        reason="geometry only; no force, strain, or retention strength is claimed",
      ),
      @common.Omission::new(
        feature="fillet-at-root",
        reason="the beam root is a sharp corner; no stress-relief fillet is modelled",
      ),
    ],
  )
  let name = "snap-latch-\{@cad.fmt_double(beam_length_mm, None)}x\{@cad.fmt_double(beam_width_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Snap latch L\{@cad.fmt_double(beam_length_mm, None)} t\{@cad.fmt_double(beam_thickness_mm, None)}",
        family="snap-fit cantilever (engineering envelope)",
        size="\{@cad.fmt_double(beam_length_mm, None)}x\{@cad.fmt_double(beam_width_mm, None)}",
        source="Parametric cantilever snap-latch envelope. No engagement force or retention rating is implied.",
      ),
      description="Cantilever snap-fit latch with a straight ramp hook. The beam root is sharp and no engagement strength is claimed.",
      features~,
    )
    .add_layer(body, name="beam", color~)
    .with_connector_unchecked(
      @common.MateConnector::new(
        "root-face",
        placement=@common.Placement::translation(
          0.0,
          beam_thickness_mm / 2.0,
          0.0,
        ),
        axis=(-1.0, 0.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=beam_thickness_mm,
        description="beam root face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "tip-face",
        placement=@common.Placement::translation(
          beam_length_mm,
          (beam_thickness_mm - hook_depth_mm) / 2.0,
          0.0,
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=beam_thickness_mm + hook_depth_mm,
        description="free-end tip face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "hook-engagement",
        placement=@common.Placement::translation(
          beam_length_mm,
          -hook_depth_mm,
          beam_width_mm / 2.0,
        ),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=beam_width_mm,
        depth_mm=hook_depth_mm,
        description="engagement depth below the beam underside",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "beam-axis",
        placement=@common.Placement::translation(0.0, 0.0, beam_width_mm / 2.0),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=beam_thickness_mm,
        depth_mm=beam_length_mm,
        description="beam axis along +X",
      ),
    ),
  )
}
