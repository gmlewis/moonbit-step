///|
/// VWheelSpec carries the boundary dimensions of a V-Slot wheel body.
///
/// The wheel body is the Delrin/POM part; the two 625 bearings and shims are
/// separate parts and are not modelled. All dimensions are millimetres.
pub(all) struct VWheelSpec {
  designation : String
  outer_diameter_mm : Double
  width_mm : Double
  /// Diameter at the bottom of the 90 degree V groove.
  groove_min_diameter_mm : Double
  /// Bearing-pocket diameter (the seat for the 625 outer rings).
  bearing_seat_diameter_mm : Double
  /// Diameter of the central hole through the mid-width spacer lip.
  axle_bore_mm : Double
  /// Axial width of the spacer lip that separates the two bearings.
  mid_lip_mm : Double
}

///|
/// VWheelSpec::openbuilds_solid_v returns the OpenBuilds solid V-wheel
/// boundary dimensions.
///
/// Published values: 23.90 mm outside diameter, 10.23 mm width, 90 degree V
/// groove 3.2 mm deep, Ø16 bearing seat for two 625 bearings, and a Ø11 hole
/// through a 1 mm mid-width spacer lip.
pub fn VWheelSpec::openbuilds_solid_v() -> VWheelSpec {
  {
    designation: "OpenBuilds solid V-wheel",
    outer_diameter_mm: 23.89,
    width_mm: 10.23,
    groove_min_diameter_mm: 17.49,
    bearing_seat_diameter_mm: 16.0,
    axle_bore_mm: 11.0,
    mid_lip_mm: 1.0,
  }
}

///|
/// VWheelSpec::validate checks the wheel proportions.
fn VWheelSpec::validate(self : VWheelSpec) -> Result[Unit, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("wheel outer diameter", self.outer_diameter_mm),
    @common.require_positive("wheel width", self.width_mm),
    @common.require_positive(
      "groove minimum diameter",
      self.groove_min_diameter_mm,
    ),
    @common.require_positive(
      "bearing seat diameter",
      self.bearing_seat_diameter_mm,
    ),
    @common.require_positive("axle bore", self.axle_bore_mm),
    @common.require_positive("mid-lip width", self.mid_lip_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if self.bearing_seat_diameter_mm <= self.axle_bore_mm {
    return Err(
      @common.InvalidParameter(
        "bearing seat diameter must exceed the axle bore",
      ),
    )
  }
  if self.groove_min_diameter_mm <= self.bearing_seat_diameter_mm {
    return Err(
      @common.InvalidParameter(
        "groove minimum diameter must exceed the bearing seat diameter",
      ),
    )
  }
  if self.outer_diameter_mm <= self.groove_min_diameter_mm {
    return Err(
      @common.InvalidParameter(
        "wheel outer diameter must exceed the groove datum",
      ),
    )
  }
  if self.width_mm <= self.mid_lip_mm {
    return Err(
      @common.InvalidParameter("wheel width must exceed the mid-lip width"),
    )
  }
  let groove_depth = (self.outer_diameter_mm - self.groove_min_diameter_mm) /
    2.0
  if groove_depth >= self.width_mm / 2.0 {
    return Err(
      @common.InvalidParameter(
        "V groove is deeper than the wheel half-width; the flanges would vanish",
      ),
    )
  }
  Ok(())
}

///|
/// v_wheel builds a V-Slot wheel body as one analytic solid of revolution.
///
/// Axis +Z, faces at `z = 0` and `z = width`. The V groove is two 45 degree
/// cones meeting at the groove datum, the bearing pockets are two cylinders,
/// and the central hole is the mid-lip bore. The bearings, shims, and any
/// thread or axle are not modelled.
pub fn v_wheel(
  spec : VWheelSpec,
  detail~ : @common.DetailLevel = Detailed,
  color~ : @cad.Rgb = @cad.Rgb::blue(),
) -> Result[@common.Component, @common.SpecError] {
  match spec.validate() {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let _ = detail
  let r_out = spec.outer_diameter_mm / 2.0
  let r_groove = spec.groove_min_diameter_mm / 2.0
  let r_seat = spec.bearing_seat_diameter_mm / 2.0
  let r_bore = spec.axle_bore_mm / 2.0
  let w = spec.width_mm
  let half = w / 2.0
  let pocket = (w - spec.mid_lip_mm) / 2.0
  let groove_depth = r_out - r_groove
  let flange_band = half - groove_depth
  // Closed (r, z) half-section, traversed around the material.
  let points : Array[@cad.Vec2] = [
    (r_bore, pocket),
    (r_bore, pocket + spec.mid_lip_mm),
    (r_seat, pocket + spec.mid_lip_mm),
    (r_seat, w),
    (r_out, w),
    (r_out, w - flange_band),
    (r_groove, half),
    (r_out, flange_band),
    (r_out, 0.0),
    (r_seat, 0.0),
    (r_seat, pocket),
  ]
  let body = @cad.RevolvedProfile::polyline(points, closed=true).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=[
      "body", "v-groove", "bearing-pocket-near", "bearing-pocket-far", "mid-spacer-lip",
      "axle-bore",
    ],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="bearings",
        reason="the 625 bearings and shims are separate parts and are not modelled",
      ),
      @common.Omission::new(
        feature="material-tolerances",
        reason="nominal geometry only; press-fit and running clearances are not asserted",
      ),
    ],
  )
  Ok(
    with_vwheel_connectors(
      @common.Component::new(
        name="v-wheel-\{@cad.fmt_double(spec.outer_diameter_mm, None)}",
        metadata=@common.Metadata::new(
          designation=spec.designation,
          standard="OpenBuilds V-Slot wheel (manufacturer part, not a universal standard)",
          family="V-Slot wheel",
          size="OD\{@cad.fmt_double(spec.outer_diameter_mm, None)} x \{@cad.fmt_double(spec.width_mm, None)}",
          source="OpenBuilds published wheel dimensions: 23.90 mm OD, 10.23 mm width, 90 degree groove, Ø16 bearing seat, Ø11 mid-lip bore.",
        ),
        description="V-Slot wheel body: 90 degree V groove for the rail lips, two Ø16 bearing pockets, and a Ø11 mid-lip bore. Bearings and shims are not modelled.",
        features~,
      ).add_layer(body, name="body", color~),
      spec,
    ),
  )
}

///|
/// with_vwheel_connectors attaches the wheel's bearing seats, axle bore,
/// V-groove datum, and both faces.
fn with_vwheel_connectors(
  component : @common.Component,
  spec : VWheelSpec,
) -> @common.Component {
  let w = spec.width_mm
  let pocket = (w - spec.mid_lip_mm) / 2.0
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "axle-bore",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=spec.axle_bore_mm,
      depth_mm=spec.mid_lip_mm,
      description="central mid-lip bore (Ø11 x 1 mm); the axle and bearings are separate parts",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "bearing-seat-a",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=spec.bearing_seat_diameter_mm,
      depth_mm=pocket,
      description="near-side 625 bearing pocket",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "bearing-seat-b",
      placement=@common.Placement::translation(0.0, 0.0, w),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=spec.bearing_seat_diameter_mm,
      depth_mm=pocket,
      description="far-side 625 bearing pocket",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "v-groove",
      placement=@common.Placement::translation(0.0, 0.0, w / 2.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::Datum,
      diameter_mm=spec.groove_min_diameter_mm,
      depth_mm=(spec.outer_diameter_mm - spec.groove_min_diameter_mm) / 2.0,
      description="90 degree V-groove datum; rides the V-Slot lips",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "face-a",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=spec.outer_diameter_mm,
      description="near face at z = 0",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "face-b",
      placement=@common.Placement::translation(0.0, 0.0, w),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=spec.outer_diameter_mm,
      description="far face at z = width",
    ),
  )
}
