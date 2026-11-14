///|
/// Minimum radial material shelf between the insert pocket and the through
/// screw-clearance bore.
const HEAT_SET_BOSS_MIN_SHELF_MM : Double = 0.1

///|
/// heat_set_boss builds a printed boss with a top heat-set insert pocket and a
/// through screw-clearance bore.
///
/// The part is one analytic solid of revolution. `insert_hole_diameter_mm` and
/// `insert_hole_depth_mm` define the blind top pocket; the screw-clearance bore
/// runs through the remaining height. `insert_diametral_clearance_mm` changes
/// the nominal pocket diameter, while `insert_fit` records declared intent
/// independently. Dimensions are true-size nominal unless the caller adds a
/// clearance. The heat-set insert, its thread, and diamond knurl are separate
/// parts or omitted features. No pull-out, torque, boss-strength, or material
/// claim is implied.
///
/// Frame: the boss axis is +Z, from `z = 0` to `boss_height_mm`; the insert
/// pocket opens at +Z.
pub fn heat_set_boss(
  boss_diameter_mm : Double,
  boss_height_mm : Double,
  insert_hole_diameter_mm : Double,
  insert_hole_depth_mm : Double,
  screw_clearance_diameter_mm : Double,
  insert_diametral_clearance_mm~ : Double = 0.0,
  insert_fit~ : @cad.Fit = @cad.Fit::Nominal,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("heat-set boss diameter", boss_diameter_mm),
    @common.require_positive("heat-set boss height", boss_height_mm),
    @common.require_positive(
      "heat-set insert hole diameter", insert_hole_diameter_mm,
    ),
    @common.require_positive("heat-set insert hole depth", insert_hole_depth_mm),
    @common.require_positive(
      "heat-set screw clearance diameter", screw_clearance_diameter_mm,
    ),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let insert_seat_diameter = insert_hole_diameter_mm +
    insert_diametral_clearance_mm
  if insert_seat_diameter >= boss_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "heat-set insert hole must be smaller than the boss diameter",
      ),
    )
  }
  if (insert_seat_diameter - screw_clearance_diameter_mm) / 2.0 <
    HEAT_SET_BOSS_MIN_SHELF_MM {
    return Err(
      @common.InvalidDimension(
        "heat-set insert hole must leave at least a \{HEAT_SET_BOSS_MIN_SHELF_MM} mm radial shelf above the screw-clearance bore",
      ),
    )
  }
  if insert_hole_depth_mm >= boss_height_mm {
    return Err(
      @common.InvalidDimension(
        "heat-set insert hole depth must be less than the boss height",
      ),
    )
  }
  let outer_r = boss_diameter_mm / 2.0
  let insert_r = insert_seat_diameter / 2.0
  let clearance_r = screw_clearance_diameter_mm / 2.0
  let body = @cad.RevolvedProfile::polyline(
    [
      (clearance_r, 0.0),
      (outer_r, 0.0),
      (outer_r, boss_height_mm),
      (insert_r, boss_height_mm),
      (insert_r, boss_height_mm - insert_hole_depth_mm),
      (clearance_r, boss_height_mm - insert_hole_depth_mm),
    ],
    closed=true,
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["boss-body", "insert-pocket", "screw-clearance-bore", "boss-faces"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="heat-set-insert-and-thread",
        reason="the insert is a separate part; its thread and diamond knurl are not modelled",
      ),
      @common.Omission::new(
        feature="manufacturing-tolerances",
        reason="the pocket is true-size nominal unless the caller declares a diametral clearance; fit intent is not a tolerance",
      ),
      @common.Omission::new(
        feature="pull-out-and-boss-strength",
        reason="geometry alone does not establish insert retention, torque capacity, or boss strength",
      ),
    ],
  )
  let component = @common.Component::new(
    name="heat-set-boss-\{@cad.fmt_double(boss_diameter_mm, None)}x\{@cad.fmt_double(boss_height_mm, None)}",
    metadata=@common.Metadata::new(
      designation="Heat-set boss Ø\{@cad.fmt_double(boss_diameter_mm, None)} x \{@cad.fmt_double(boss_height_mm, None)}, Ø\{@cad.fmt_double(insert_seat_diameter, None)} x \{@cad.fmt_double(insert_hole_depth_mm, None)} pocket",
      family="heat-set boss",
      size="boss Ø\{@cad.fmt_double(boss_diameter_mm, None)} x \{@cad.fmt_double(boss_height_mm, None)}",
      source="Parametric heat-set boss; M3 x 4 preset follows Xem Studio's CC BY 4.0 reference (Ø7.6 x 8, Ø4.4 x 5 pocket, Ø3.4 through clearance).",
    ),
    description="Printed boss with an analytic blind heat-set insert pocket and a through screw-clearance bore. True-size nominal geometry; fit is declared intent, not retention or strength. No material or pull-out rating is implied.",
    features~,
  ).add_layer(body, name="body", color~)
  Ok(
    with_heat_set_boss_connectors(
      component, boss_diameter_mm, boss_height_mm, insert_seat_diameter, insert_hole_depth_mm,
      screw_clearance_diameter_mm, insert_diametral_clearance_mm, insert_fit,
    ),
  )
}

///|
/// with_heat_set_boss_connectors attaches the insert pocket, screw clearance,
/// outer seat, and both end faces.
fn with_heat_set_boss_connectors(
  component : @common.Component,
  boss_diameter_mm : Double,
  boss_height_mm : Double,
  insert_seat_diameter_mm : Double,
  insert_depth_mm : Double,
  screw_clearance_diameter_mm : Double,
  insert_clearance_mm : Double,
  insert_fit : @cad.Fit,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "insert-pocket",
      placement=@common.Placement::translation(0.0, 0.0, boss_height_mm),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=insert_seat_diameter_mm,
      depth_mm=insert_depth_mm,
      fit=insert_fit,
      description="blind heat-set insert pocket, entered from +Z; diametral clearance \{@cad.fmt_double(insert_clearance_mm, None)} mm; fit is declared intent, not retention",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "screw-clearance",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=screw_clearance_diameter_mm,
      depth_mm=boss_height_mm,
      fit=@cad.Fit::Free,
      description="through screw-clearance bore from the base into the insert pocket",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "outer-seat",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=boss_diameter_mm,
      depth_mm=boss_height_mm,
      description="outside cylindrical boss surface",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "boss-base",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=boss_diameter_mm,
      description="base face; outward normal -Z",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "boss-top",
      placement=@common.Placement::translation(0.0, 0.0, boss_height_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=boss_diameter_mm,
      description="top annular face around the insert pocket",
    ),
  )
}

///|
/// heat_set_boss_m3x4 builds the measured CC BY 4.0 Xem Studio M3 x 4 boss:
/// Ø7.6 x 8 mm with a Ø4.4 x 5 mm pocket and Ø3.4 through clearance bore.
pub fn heat_set_boss_m3x4(
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  heat_set_boss(7.6, 8.0, 4.4, 5.0, 3.4, color~)
}
