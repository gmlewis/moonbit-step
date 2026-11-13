///|
/// smooth_idler builds a flanged smooth idler (a plain pulley without teeth).
///
/// Frame: the hub runs from `z = 0` to `z = width`; the bore runs through the
/// full height. With flanges, one annular flange lies at `z = -flange_thickness`
/// to `0` and the other at `z = width` to `z = width + flange_thickness`, both
/// sharing the bore. Without flanges the part runs from `z = 0` to `z = width`.
///
/// The idler is a generic parametric primitive. Dimensions are caller-supplied;
/// no vendor part, bearing bore tolerance, or load rating is implied. The bore
/// runs on a shaft or bearing; it is not a bearing seat unless the caller sizes
/// it as one.
pub fn smooth_idler(
  outer_diameter_mm : Double,
  bore_diameter_mm : Double,
  width_mm : Double,
  flange_diameter_mm~ : Double = 0.0,
  flange_thickness_mm~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("idler outer diameter", outer_diameter_mm),
    @common.require_positive("idler bore", bore_diameter_mm),
    @common.require_positive("idler width", width_mm),
    @common.require_non_negative("idler flange diameter", flange_diameter_mm),
    @common.require_non_negative("idler flange thickness", flange_thickness_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if bore_diameter_mm >= outer_diameter_mm {
    return Err(
      @common.InvalidParameter(
        "idler bore must be smaller than its outer diameter",
      ),
    )
  }
  let flanged = flange_diameter_mm > 0.0 || flange_thickness_mm > 0.0
  if flanged {
    if flange_diameter_mm < outer_diameter_mm {
      return Err(
        @common.InvalidParameter(
          "idler flange diameter must be at least the hub outer diameter",
        ),
      )
    }
    if flange_thickness_mm <= 0.0 {
      return Err(
        @common.InvalidParameter("idler flange needs a positive thickness"),
      )
    }
  }
  let bore_half = bore_diameter_mm / 2.0
  let hub_outer = spacer_circle_loop(0.0, 0.0, outer_diameter_mm / 2.0)
  let bore = spacer_circle_loop(0.0, 0.0, bore_half)
  let hub = @cad.ExtrudedArcProfile::new(hub_outer, width_mm, holes=[bore]).as_shape()
  let flange_diameter = if flanged { flange_diameter_mm } else { 0.0 }
  let flange_thickness = if flanged { flange_thickness_mm } else { 0.0 }
  let flange = if flanged {
    Some(
      @cad.ExtrudedArcProfile::new(
        spacer_circle_loop(0.0, 0.0, flange_diameter_mm / 2.0),
        flange_thickness_mm,
        holes=[spacer_circle_loop(0.0, 0.0, bore_half)],
      ).as_shape(),
    )
  } else {
    None
  }
  let bottom_z = -flange_thickness
  let top_z = width_mm + flange_thickness
  let total_depth = width_mm + 2.0 * flange_thickness
  let features = @common.FeatureRecord::new(
    modeled=if flanged {
      ["hub", "through-bore", "end-flanges"]
    } else {
      ["hub", "through-bore"]
    },
    omitted=[
      @common.Omission::new(
        feature="bearing-seat-tolerance",
        reason="the bore is a nominal cylindrical hole; no bearing fit or tolerance class is asserted",
      ),
      @common.Omission::new(
        feature="edge-chamfer",
        reason="not modelled by this builder",
      ),
    ],
  )
  let mut component = @common.Component::new(
    name="smooth-idler-\{@cad.fmt_double(outer_diameter_mm, None)}x\{@cad.fmt_double(width_mm, None)}",
    metadata=@common.Metadata::new(
      designation="Smooth idler OD \{@cad.fmt_double(outer_diameter_mm, None)} / bore \{@cad.fmt_double(bore_diameter_mm, None)} x \{@cad.fmt_double(width_mm, None)}",
      family="smooth idler",
      length_mm=total_depth,
      source="Generic parametric smooth idler: hub tube plus optional annular end flanges. No vendor part or bearing-seat tolerance is implied.",
    ),
    description="Smooth idler (toothless pulley) with a through bore and optional annular end flanges. Layered analytic cylinders; no bearing rating or belt-tension claim.",
    features~,
  ).add_layer(hub, name="hub", color~)
  if flanged {
    match flange {
      Some(shape) =>
        component = component
          .add_layer(
            shape,
            name="flange-bottom",
            color~,
            placement=@common.Placement::translation(0.0, 0.0, bottom_z),
          )
          .add_layer(
            shape,
            name="flange-top",
            color~,
            placement=@common.Placement::translation(0.0, 0.0, width_mm),
          )
      None => ()
    }
  }
  component = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore",
        placement=@common.Placement::translation(0.0, 0.0, bottom_z),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bore_diameter_mm,
        depth_mm=total_depth,
        description="through bore; entered from the negative-Z face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "outer-seat",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=outer_diameter_mm,
        depth_mm=width_mm,
        description="outer running surface of the hub",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-negative",
        placement=@common.Placement::translation(0.0, 0.0, bottom_z),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=if flanged { flange_diameter_mm } else { outer_diameter_mm },
        description="negative-Z end face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-positive",
        placement=@common.Placement::translation(0.0, 0.0, top_z),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=if flanged { flange_diameter_mm } else { outer_diameter_mm },
        description="positive-Z end face",
      ),
    )
  if flanged {
    component = component.with_connector_unchecked(
      @common.MateConnector::new(
        "flange-seat",
        placement=@common.Placement::translation(0.0, 0.0, bottom_z),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=flange_diameter,
        depth_mm=total_depth,
        description="outer flange rim; the flanges guide the belt",
      ),
    )
  }
  Ok(component)
}
