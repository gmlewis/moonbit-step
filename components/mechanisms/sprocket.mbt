///|
/// SprocketSpec describes a roller-chain sprocket tooth envelope.
///
/// The tooth profile is a measured line/arc envelope calibrated against the
/// CC0 Innerscene ANSI #40 16T and 24T references and re-encoded here as
/// original parametric data. For other tooth counts the tip-arc half-angle
/// defaults to the fitted engineering envelope
/// `(180/z) * (0.1901 + 1.4736/z)` degrees; pass `tip_arc_half_angle_deg` to
/// override it.
pub(all) struct SprocketSpec {
  pitch_mm : Double
  teeth : Int32
  roller_diameter_mm : Double
  seat_clearance_mm : Double
  plate_thickness_mm : Double
  hub_diameter_mm : Double
  hub_height_mm : Double
  bore_diameter_mm : Double
  tip_arc_half_angle_deg : Double
}

///|
/// sprocket_tip_arc_half_angle_deg returns the fitted tip-arc half-angle.
///
/// The fit passes exactly through the measured ANSI #40 16T and 24T values
/// (3.175 and 1.886 degrees). It is an engineering envelope for other counts.
pub fn sprocket_tip_arc_half_angle_deg(teeth : Int32) -> Double {
  let z = teeth.to_double()
  180.0 / z * (0.1901 + 1.4736 / z)
}

///|
/// roller_chain_sprocket_spec validates a roller-chain sprocket specification.
pub fn roller_chain_sprocket_spec(
  pitch_mm~ : Double,
  teeth~ : Int32,
  roller_diameter_mm~ : Double,
  seat_clearance_mm~ : Double = 0.09,
  plate_thickness_mm~ : Double = 7.6,
  hub_diameter_mm~ : Double = 20.0,
  hub_height_mm~ : Double = 5.0,
  bore_diameter_mm~ : Double = 10.0,
  tip_arc_half_angle_deg? : Double,
) -> Result[SprocketSpec, @common.SpecError] {
  match
    mechanism_checks([
      ("sprocket pitch", pitch_mm),
      ("sprocket roller diameter", roller_diameter_mm),
      ("sprocket plate thickness", plate_thickness_mm),
      ("sprocket bore diameter", bore_diameter_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match
    mechanism_non_negative_checks([
      ("sprocket seat clearance", seat_clearance_mm),
      ("sprocket hub height", hub_height_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if teeth < 9 {
    return Err(
      @common.InvalidParameter("roller-chain sprocket needs at least 9 teeth"),
    )
  }
  let z = teeth.to_double()
  let pitch_radius = pitch_mm / (2.0 * @math.sin(@math.PI / z))
  let tip_radius = pitch_mm *
    (0.6 + @math.cos(@math.PI / z) / @math.sin(@math.PI / z)) /
    2.0
  let seat_radius = roller_diameter_mm / 2.0 + seat_clearance_mm
  if seat_radius >= pitch_radius {
    return Err(
      @common.InvalidDimension(
        "sprocket roller seat does not fit the pitch radius",
      ),
    )
  }
  if tip_radius <= pitch_radius {
    return Err(
      @common.InvalidDimension(
        "sprocket tip radius must exceed the pitch radius",
      ),
    )
  }
  if bore_diameter_mm >= hub_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "sprocket bore must be smaller than the hub diameter",
      ),
    )
  }
  if hub_diameter_mm / 2.0 >= pitch_radius - seat_radius {
    return Err(
      @common.InvalidDimension(
        "sprocket hub does not fit inside the tooth roots",
      ),
    )
  }
  let beta = match tip_arc_half_angle_deg {
    Some(v) => v
    None => sprocket_tip_arc_half_angle_deg(teeth)
  }
  if !@common.is_finite(beta) || beta <= 0.0 || beta >= 180.0 / z {
    return Err(
      @common.InvalidParameter(
        "sprocket tip-arc half-angle must be positive and smaller than half a tooth pitch",
      ),
    )
  }
  Ok({
    pitch_mm,
    teeth,
    roller_diameter_mm,
    seat_clearance_mm,
    plate_thickness_mm,
    hub_diameter_mm,
    hub_height_mm,
    bore_diameter_mm,
    tip_arc_half_angle_deg: beta,
  })
}

///|
/// ansi40_sprocket_spec returns the CC0-reference-calibrated ANSI #40 spec.
///
/// Pitch 12.7 mm, roller 7.9 mm, 0.09 mm seat clearance, 7.6 mm tooth plate,
/// Ø20 x 5 mm hub on the +Z side, and a Ø10 bore. The 16T and 24T outlines
/// reproduce the measured references; other counts use the fitted tip angle.
pub fn ansi40_sprocket_spec(
  teeth : Int32,
) -> Result[SprocketSpec, @common.SpecError] {
  roller_chain_sprocket_spec(pitch_mm=12.7, teeth~, roller_diameter_mm=7.9)
}

///|
/// sprocket_tooth_loop returns the counter-clockwise measured tooth envelope.
///
/// Each pitch interval has a 180-degree roller seat (split into two 90-degree
/// minor arcs through the inner point), a straight flank to the tooth tip, and
/// a convex tip arc centred on the sprocket axis. The tip arcs are at the
/// midpoints between pitch points.
fn sprocket_tooth_loop(
  pitch_radius_mm : Double,
  seat_radius_mm : Double,
  tip_radius_mm : Double,
  tip_arc_half_angle_deg : Double,
  teeth : Int32,
) -> Array[@cad.ProfileSegment] {
  let z = teeth.to_double()
  let step = 2.0 * @math.PI / z
  let beta = tip_arc_half_angle_deg * @math.PI / 180.0
  let segments : Array[@cad.ProfileSegment] = []
  for i in 0..<teeth {
    let phi = step * i.to_double()
    let cos_phi = @math.cos(phi)
    let sin_phi = @math.sin(phi)
    let cos_t = -sin_phi
    let sin_t = cos_phi
    let cx = pitch_radius_mm * cos_phi
    let cy = pitch_radius_mm * sin_phi
    let seat_bottom = (cx - seat_radius_mm * cos_t, cy - seat_radius_mm * sin_t)
    let seat_top = (cx + seat_radius_mm * cos_t, cy + seat_radius_mm * sin_t)
    let seat_inner = (
      cx - seat_radius_mm * cos_phi,
      cy - seat_radius_mm * sin_phi,
    )
    segments.push(@cad.SegmentArc(seat_bottom, seat_inner, (cx, cy)))
    segments.push(@cad.SegmentArc(seat_inner, seat_top, (cx, cy)))
    let tip_center = phi + step / 2.0
    let tip_left = (
      tip_radius_mm * @math.cos(tip_center - beta),
      tip_radius_mm * @math.sin(tip_center - beta),
    )
    let tip_right = (
      tip_radius_mm * @math.cos(tip_center + beta),
      tip_radius_mm * @math.sin(tip_center + beta),
    )
    segments.push(@cad.SegmentLine(seat_top, tip_left))
    segments.push(@cad.SegmentArc(tip_left, tip_right, (0.0, 0.0)))
    let next_phi = phi + step
    let next_bottom = (
      pitch_radius_mm * @math.cos(next_phi) +
      seat_radius_mm * @math.sin(next_phi),
      pitch_radius_mm * @math.sin(next_phi) -
      seat_radius_mm * @math.cos(next_phi),
    )
    segments.push(@cad.SegmentLine(tip_right, next_bottom))
  }
  segments
}

///|
/// sprocket builds a roller-chain sprocket with a measured line/arc tooth
/// envelope and an optional one-sided hub.
///
/// Frame: the sprocket axis is +Z, the tooth plate spans `z = 0 ..
/// plate_thickness`, and a positive `hub_height` adds a coaxial hub from
/// `plate_thickness` to the total height. The bore is a real through hole. The
/// tooth profile is a calibrated engineering envelope, not a production tooth
/// form; no chain engagement, load, or fatigue rating is claimed.
///
/// The plate and hub are separate layers; use `write_step_evaluated` for one
/// fused manifold.
pub fn sprocket(
  spec : SprocketSpec,
) -> Result[@common.Component, @common.SpecError] {
  let z = spec.teeth.to_double()
  let pitch_radius = spec.pitch_mm / (2.0 * @math.sin(@math.PI / z))
  let tip_radius = spec.pitch_mm *
    (0.6 + @math.cos(@math.PI / z) / @math.sin(@math.PI / z)) /
    2.0
  let seat_radius = spec.roller_diameter_mm / 2.0 + spec.seat_clearance_mm
  let bore_radius = spec.bore_diameter_mm / 2.0
  let outline = sprocket_tooth_loop(
    pitch_radius,
    seat_radius,
    tip_radius,
    spec.tip_arc_half_angle_deg,
    spec.teeth,
  )
  let plate = @cad.ExtrudedArcProfile::new(outline, spec.plate_thickness_mm, holes=[
    circle_loop(0.0, 0.0, bore_radius),
  ])
  if !plate.validate() {
    return Err(
      @common.InvalidParameter(
        "sprocket tooth profile did not form a valid loop",
      ),
    )
  }
  let has_hub = spec.hub_height_mm > 0.0
  let total_height = spec.plate_thickness_mm + spec.hub_height_mm
  let measured = spec.teeth == 16 || spec.teeth == 24
  let modeled : Array[String] = ["tooth-envelope", "plate", "bore"]
  if has_hub {
    modeled.push("hub")
  }
  let approximated : Array[@common.Approximation] = if measured {
    []
  } else {
    [
      @common.Approximation::new(
        feature="tooth-tip-angle",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="tip_arc_half_angle_deg=\{spec.tip_arc_half_angle_deg}",
      ),
    ]
  }
  let features = @common.FeatureRecord::new(modeled~, approximated~, omitted=[
    @common.Omission::new(
      feature="chain-engagement-and-strength",
      reason="the tooth envelope carries no chain load, wear, or fatigue rating",
    ),
    @common.Omission::new(
      feature="plate-to-hub-union",
      reason="the plate and hub abut nominally; use write_step_evaluated for one manifold",
    ),
  ])
  let name = "sprocket-p\{@cad.fmt_double(spec.pitch_mm, None)}-z\{spec.teeth}"
  let mut out = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Roller-chain sprocket p\{@cad.fmt_double(spec.pitch_mm, None)} z\{spec.teeth}",
      standard="ANSI #40 / ISO 606 pitch (measured CC0 outline)",
      family="roller-chain sprocket (engineering envelope)",
      size="p\{@cad.fmt_double(spec.pitch_mm, None)}-z\{spec.teeth}",
      source="Measured CC0 ANSI #40 16T/24T outlines re-encoded as original line/arc data; other counts use the fitted tip-angle envelope.",
    ),
    description="Roller-chain sprocket with a measured line/arc tooth envelope, real bore, and optional one-sided hub. No chain engagement or load rating is implied.",
    features~,
  ).add_layer(plate.as_shape(), name="tooth-plate", color=@cad.Rgb::grey())
  if has_hub {
    out = out.add_layer(
      @cad.RevolvedProfile::tube(
        spec.hub_diameter_mm,
        spec.bore_diameter_mm,
        spec.hub_height_mm,
      ).as_shape(),
      name="hub",
      color=@cad.Rgb::grey(),
      placement=@common.Placement::translation(
        0.0,
        0.0,
        spec.plate_thickness_mm,
      ),
    )
  }
  out = out
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=spec.bore_diameter_mm,
        depth_mm=total_height,
        description="through shaft bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pitch-circle",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          spec.plate_thickness_mm / 2.0,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=2.0 * pitch_radius,
        depth_mm=spec.plate_thickness_mm,
        description="pitch-circle datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "plate-face",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * tip_radius,
        description="tooth-plate negative-Z face",
      ),
    )
  if has_hub {
    out = out
      .with_connector_unchecked(
        @common.MateConnector::new(
          "hub-seat",
          placement=@common.Placement::translation(
            0.0,
            0.0,
            spec.plate_thickness_mm,
          ),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::CylindricalShaft,
          gender=@common.MateGender::Male,
          diameter_mm=spec.hub_diameter_mm,
          depth_mm=spec.hub_height_mm,
          description="hub outside diameter seat",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "hub-face",
          placement=@common.Placement::translation(0.0, 0.0, total_height),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::PlaneFace,
          diameter_mm=spec.hub_diameter_mm,
          description="hub positive-Z face",
        ),
      )
  }
  Ok(out)
}

///|
/// ansi40_sprocket builds an ANSI #40 sprocket with the reference-calibrated
/// envelope.
pub fn ansi40_sprocket(
  teeth : Int32,
) -> Result[@common.Component, @common.SpecError] {
  match ansi40_sprocket_spec(teeth) {
    Err(e) => Err(e)
    Ok(spec) => sprocket(spec)
  }
}

///|
/// sprocket_pitch_radius_mm returns the pitch-circle radius for a tooth count.
pub fn sprocket_pitch_radius_mm(pitch_mm : Double, teeth : Int32) -> Double {
  pitch_mm / (2.0 * @math.sin(@math.PI / teeth.to_double()))
}

///|
/// roller_chain_path_length_mm returns the open-chain pitch-path length around
/// two sprockets.
///
/// The helper reuses the exact open-belt tangent length at the two sprocket
/// pitch circles: `pi (R1 + R2) + 2 alpha (R2 - R1) +
/// 2 sqrt(C^2 - (R2 - R1)^2)` with `alpha = asin((R2 - R1) / C)`. Chain links
/// and rollers are not modelled.
pub fn roller_chain_path_length_mm(
  pitch_mm : Double,
  teeth_a : Int32,
  teeth_b : Int32,
  center_distance_mm : Double,
) -> Result[Double, @common.SpecError] {
  match
    mechanism_checks([
      ("chain pitch", pitch_mm),
      ("chain centre distance", center_distance_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if teeth_a < 9 || teeth_b < 9 {
    return Err(
      @common.InvalidParameter(
        "roller-chain path needs at least 9 teeth per sprocket",
      ),
    )
  }
  let r1 = sprocket_pitch_radius_mm(pitch_mm, teeth_a)
  let r2 = sprocket_pitch_radius_mm(pitch_mm, teeth_b)
  if (r2 - r1).abs() >= center_distance_mm {
    return Err(
      @common.InvalidDimension(
        "chain centre distance must exceed the sprocket pitch-radius difference",
      ),
    )
  }
  Ok(belt_pitch_length_mm_unequal(2.0 * r1, 2.0 * r2, center_distance_mm))
}
