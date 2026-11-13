///|
/// Minimum material between a mounting hole edge and the plate edge.
const NEMA_PLATE_MARGIN_MM : Double = 3.0

///|
/// nema_mounting_plate builds a flat plate with a NEMA motor bolt pattern, a
/// central pilot clearance bore, and four mounting holes.
///
/// The plate is centred on the XY origin with faces at `z = +/- thickness/2`.
/// Hole positions use the frame's bolt spacing. The geometric holes include the
/// requested diametral clearance; the connector diameters remain the frame's
/// nominal interface values so `fit` expresses the clearance intent.
///
/// This is a generic plate blank with a standard motor interface. It does not
/// assert material strength, stiffness, or a particular commercial part.
pub fn nema_mounting_plate(
  frame : NemaFrame,
  plate_width_mm : Double,
  plate_height_mm : Double,
  thickness_mm : Double,
  hole_clearance_mm~ : Double = 0.2,
  detail~ : @common.DetailLevel = @common.DetailLevel::Detailed,
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("NEMA plate width", plate_width_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("NEMA plate height", plate_height_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("NEMA plate thickness", thickness_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match
    @common.require_non_negative("NEMA plate hole clearance", hole_clearance_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let half = frame.bolt_spacing_mm / 2.0
  let hole_d = frame.mounting_hole_diameter_mm + 2.0 * hole_clearance_mm
  let pilot_d = frame.pilot_diameter_mm + 2.0 * hole_clearance_mm
  if plate_width_mm <
    frame.bolt_spacing_mm + hole_d + 2.0 * NEMA_PLATE_MARGIN_MM ||
    plate_height_mm <
    frame.bolt_spacing_mm + hole_d + 2.0 * NEMA_PLATE_MARGIN_MM {
    return Err(
      @common.InvalidDimension(
        "NEMA plate is too small for the bolt pattern plus edge margin",
      ),
    )
  }
  let holes : Array[@stock.PlateHole] = [
    @stock.PlateHole::{ x_mm: 0.0, y_mm: 0.0, diameter_mm: pilot_d, },
    @stock.PlateHole::{ x_mm: half, y_mm: half, diameter_mm: hole_d, },
    @stock.PlateHole::{ x_mm: -half, y_mm: half, diameter_mm: hole_d, },
    @stock.PlateHole::{ x_mm: -half, y_mm: -half, diameter_mm: hole_d, },
    @stock.PlateHole::{ x_mm: half, y_mm: -half, diameter_mm: hole_d, },
  ]
  let plate = match
    @stock.plate(plate_width_mm, plate_height_mm, thickness_mm, holes~, detail~) {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  let name = "\{frame.designation}-mounting-plate-\{@cad.fmt_double(plate_width_mm, None)}x\{@cad.fmt_double(plate_height_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}"
  let component = plate
    .with_name(name)
    .with_metadata(
      @common.Metadata::new(
        designation="\{frame.designation} mounting plate",
        standard="NEMA motor frame interface; generic plate blank",
        family="motor mounting plate",
        size=frame.designation,
        length_mm=thickness_mm,
        source="Bolt spacing, mounting-hole diameter, and pilot diameter from the NEMA frame table. Plate size, thickness, and clearances are caller parameters; no structural rating is implied.",
      ),
    )
    .with_description(
      "Flat motor mounting plate with a central pilot clearance bore and four NEMA bolt holes. Generic blank; no stiffness, strength, or commercial-part claim.",
    )
    .with_features(
      @common.FeatureRecord::new(
        modeled=[
          "plate", "nema-pilot-bore", "nema-bolt-pattern", "through-holes",
        ],
        omitted=[
          @common.Omission::new(
            feature="mounting-slots",
            reason="holes are circular; slot adjustment is not modelled",
          ),
          @common.Omission::new(
            feature="edge-treatment",
            reason="no chamfer, fillet, or deburr is asserted",
          ),
          @common.Omission::new(
            feature="structural-rating",
            reason="geometry only; plate stiffness and strength require analysis and testing",
          ),
        ],
      ),
    )
  let bottom = -thickness_mm / 2.0
  let top = thickness_mm / 2.0
  let face_size = if plate_width_mm < plate_height_mm {
    plate_width_mm
  } else {
    plate_height_mm
  }
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "mounting-face",
        placement=@common.Placement::translation(0.0, 0.0, bottom),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=face_size,
        description="face the motor presses against; outward normal is -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "top-face",
        placement=@common.Placement::translation(0.0, 0.0, top),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=face_size,
        description="opposite face; outward normal is +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pilot-bore",
        placement=@common.Placement::translation(0.0, 0.0, bottom),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=frame.pilot_diameter_mm,
        depth_mm=thickness_mm,
        fit=@cad.Fit::Free,
        description="central pilot clearance bore; nominal diameter with declared Free fit",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "mounting-pattern",
        placement=@common.Placement::translation(0.0, 0.0, bottom),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=frame.bolt_spacing_mm,
        description="four-hole NEMA pattern datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-1",
        placement=@common.Placement::translation(half, half, bottom),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=frame.mounting_hole_diameter_mm,
        depth_mm=thickness_mm,
        fit=@cad.Fit::Free,
        description="mounting hole at (+X,+Y)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-2",
        placement=@common.Placement::translation(-half, half, bottom),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=frame.mounting_hole_diameter_mm,
        depth_mm=thickness_mm,
        fit=@cad.Fit::Free,
        description="mounting hole at (-X,+Y)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-3",
        placement=@common.Placement::translation(-half, -half, bottom),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=frame.mounting_hole_diameter_mm,
        depth_mm=thickness_mm,
        fit=@cad.Fit::Free,
        description="mounting hole at (-X,-Y)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-4",
        placement=@common.Placement::translation(half, -half, bottom),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=frame.mounting_hole_diameter_mm,
        depth_mm=thickness_mm,
        fit=@cad.Fit::Free,
        description="mounting hole at (+X,-Y)",
      ),
    ),
  )
}
