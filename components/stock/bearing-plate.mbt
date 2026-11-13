///|
/// bearing_plate builds a printed-to-metal bearing plate: a flat plate with a
/// central bearing seat and two fastener clearance holes.
///
/// Frame: the plate is centred on the XY origin with faces at
/// `z = +/- thickness/2`, matching `plate`. The bearing seat is a through bore
/// at the origin; its diameter is `bearing_outside_diameter_mm + bore_fit_mm`.
/// A positive `bore_fit_mm` is a clearance, zero is nominal, and a negative
/// value is a press interference. The fit token on the `bearing-seat`
/// connector records the declared intent; it is a geometric declaration, not a
/// strength or retention claim. The two bolt holes lie on the X axis at
/// `+/- bolt_spacing_mm/2` and are declared free clearance holes.
///
/// Use this as a printed housing plate for a standard bearing envelope. The
/// plate does not model a housing shoulder, retaining feature, or material
/// behaviour; choose the fit from the printer's measured hole shrinkage.
pub fn bearing_plate(
  bearing_outside_diameter_mm : Double,
  bore_fit_mm : Double,
  width_mm : Double,
  height_mm : Double,
  thickness_mm : Double,
  bolt_hole_diameter_mm : Double,
  bolt_spacing_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive(
      "bearing plate bearing diameter", bearing_outside_diameter_mm,
    ),
    @common.require_positive("bearing plate width", width_mm),
    @common.require_positive("bearing plate height", height_mm),
    @common.require_positive("bearing plate thickness", thickness_mm),
    @common.require_positive(
      "bearing plate bolt hole diameter", bolt_hole_diameter_mm,
    ),
    @common.require_positive("bearing plate bolt spacing", bolt_spacing_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let seat = bearing_outside_diameter_mm + bore_fit_mm
  if seat <= 0.0 {
    return Err(
      @common.InvalidDimension(
        "bearing plate bore fit leaves a non-positive bearing seat",
      ),
    )
  }
  if seat / 2.0 >= width_mm / 2.0 || seat / 2.0 >= height_mm / 2.0 {
    return Err(
      @common.InvalidDimension(
        "bearing plate bearing seat does not fit inside the plate",
      ),
    )
  }
  let hole_x = bolt_spacing_mm / 2.0
  let overlap_gap = hole_x - seat / 2.0 - bolt_hole_diameter_mm / 2.0
  if overlap_gap <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "bearing plate bolt holes overlap the bearing seat",
      ),
    )
  }
  if hole_x + bolt_hole_diameter_mm / 2.0 >= width_mm / 2.0 ||
    bolt_hole_diameter_mm / 2.0 >= height_mm / 2.0 {
    return Err(
      @common.InvalidDimension(
        "bearing plate bolt holes do not fit inside the plate",
      ),
    )
  }
  let holes : Array[PlateHole] = [
    { x_mm: 0.0, y_mm: 0.0, diameter_mm: seat, },
    { x_mm: -hole_x, y_mm: 0.0, diameter_mm: bolt_hole_diameter_mm, },
    { x_mm: hole_x, y_mm: 0.0, diameter_mm: bolt_hole_diameter_mm, },
  ]
  let base = match
    plate_impl(width_mm, height_mm, thickness_mm, holes, [], color) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let seat_fit = if bore_fit_mm < 0.0 {
    @cad.Fit::Press
  } else if bore_fit_mm > 0.0 {
    @cad.Fit::Free
  } else {
    @cad.Fit::Nominal
  }
  let fit_note = if bore_fit_mm < 0.0 {
    "declared press interference of \{@cad.fmt_double(-bore_fit_mm, None)} mm"
  } else if bore_fit_mm > 0.0 {
    "declared radial clearance of \{@cad.fmt_double(bore_fit_mm, None)} mm"
  } else {
    "nominal bore, no declared clearance or interference"
  }
  let half = thickness_mm / 2.0
  let face_size = if width_mm < height_mm { width_mm } else { height_mm }
  let component = base
    .with_name(
      "bearing-plate-\{@cad.fmt_double(bearing_outside_diameter_mm, None)}",
    )
    .with_metadata(
      @common.Metadata::new(
        designation="Bearing plate \{@cad.fmt_double(seat, None)} seat for OD \{@cad.fmt_double(bearing_outside_diameter_mm, None)}",
        family="bearing-to-printed housing plate",
        size="\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(height_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}",
        source="Parametric printed housing plate: a central bearing seat and two fastener clearance holes. The seat fit is declared by the caller; printer shrinkage, material, and retention are not modelled.",
      ),
    )
    .with_description(
      "Flat plate with a central bearing seat and two free-clearance bolt holes. The seat fit is a geometric declaration (" +
      fit_note +
      "), not a strength or retention claim.",
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-top",
        placement=@common.Placement::translation(0.0, 0.0, half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=face_size,
        description="top face; outward normal is +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-bottom",
        placement=@common.Placement::translation(0.0, 0.0, -half),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=face_size,
        description="bottom face; outward normal is -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bearing-seat",
        placement=@common.Placement::translation(0.0, 0.0, -half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=seat,
        depth_mm=thickness_mm,
        fit=seat_fit,
        description="bearing outer-ring seat through the plate; " + fit_note,
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-1",
        placement=@common.Placement::translation(-hole_x, 0.0, -half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bolt_hole_diameter_mm,
        depth_mm=thickness_mm,
        fit=@cad.Fit::Free,
        description="fastener clearance hole",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-2",
        placement=@common.Placement::translation(hole_x, 0.0, -half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bolt_hole_diameter_mm,
        depth_mm=thickness_mm,
        fit=@cad.Fit::Free,
        description="fastener clearance hole",
      ),
    )
  Ok(component)
}
