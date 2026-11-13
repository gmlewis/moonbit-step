///|
/// LinearBearingSize carries the boundary dimensions of an LM-series linear
/// ball bushing: bore `d`, outside diameter `D`, and length `L`.
///
/// This is catalogue boundary data, not internal race or ball geometry.
pub(all) struct LinearBearingSize {
  designation : String
  bore_mm : Double
  outer_mm : Double
  length_mm : Double
}

///|
/// linear_bearing_size looks up a common LM-series linear bushing.
pub fn linear_bearing_size(
  designation : String,
) -> Result[LinearBearingSize, @common.SpecError] {
  let token = designation.trim().to_owned().to_upper()
  let (d, outer, length) = match token {
    "LM6UU" => (6.0, 12.0, 19.0)
    "LM8UU" => (8.0, 15.0, 24.0)
    "LM10UU" => (10.0, 19.0, 29.0)
    "LM12UU" => (12.0, 21.0, 30.0)
    "LM16UU" => (16.0, 28.0, 37.0)
    "LM20UU" => (20.0, 32.0, 42.0)
    other =>
      return Err(
        @common.InvalidSize(
          "unsupported linear bearing: \{other}; supported: LM6UU, LM8UU, LM10UU, LM12UU, LM16UU, LM20UU",
        ),
      )
  }
  Ok({ designation: token, bore_mm: d, outer_mm: outer, length_mm: length, })
}

///|
/// linear_bearing_designations returns every supported LM-series designation.
pub fn linear_bearing_designations() -> Array[String] {
  ["LM6UU", "LM8UU", "LM10UU", "LM12UU", "LM16UU", "LM20UU"]
}

///|
/// linear_bearing builds an LM-series linear ball-bushing envelope.
///
/// Geometry, axis +Z with the bottom face at `z = 0`:
/// - a cylindrical outside surface with a shallow retaining groove near each
///   end (the groove proportions are scaled from the LM8UU reference);
/// - a plain bore with a short counterbore at each end;
/// - sharp end faces.
///
/// The model is an envelope. Rolling elements, the cage, seals, and ball-return
/// grooves are omitted. It is not a claim of catalogue-internal geometry or of
/// load capacity. `detail` is accepted for API consistency; the envelope is
/// identical at every detail level.
pub fn linear_bearing(
  size : LinearBearingSize,
  detail~ : @common.DetailLevel = @common.DetailLevel::Detailed,
  orient_to_reference~ : Bool = false,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("linear bearing bore", size.bore_mm),
    @common.require_positive("linear bearing outside diameter", size.outer_mm),
    @common.require_positive("linear bearing length", size.length_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let r_bore = size.bore_mm / 2.0
  let r_outer = size.outer_mm / 2.0
  let length = size.length_mm
  if r_outer <= r_bore {
    return Err(
      @common.InvalidDimension(
        "linear bearing outside diameter must exceed the bore",
      ),
    )
  }
  let groove_width = 0.0458333 * length
  let groove_start = 0.1375 * length
  let groove_end = groove_start + groove_width
  let groove_depth = 0.0233333 * size.outer_mm
  let r_groove = r_outer - groove_depth
  let counterbore_diameter = 1.55 * size.bore_mm
  let counterbore_depth = 0.0583333 * length
  let r_counterbore = counterbore_diameter / 2.0
  if r_groove <= r_bore || r_groove >= r_outer {
    return Err(
      @common.InvalidDimension("linear bearing retaining groove leaves no wall"),
    )
  }
  if counterbore_depth >= length / 2.0 || r_counterbore >= r_outer {
    return Err(
      @common.InvalidDimension(
        "linear bearing end counterbores do not fit the bushing",
      ),
    )
  }
  let g1s = groove_start
  let g1e = groove_end
  let g2s = length - groove_end
  let g2e = length - groove_start
  let cb = counterbore_depth
  let points : Array[@cad.Vec2] = [
    (r_bore, 0.0),
    (r_outer, 0.0),
    (r_outer, g1s),
    (r_groove, g1s),
    (r_groove, g1e),
    (r_outer, g1e),
    (r_outer, g2s),
    (r_groove, g2s),
    (r_groove, g2e),
    (r_outer, g2e),
    (r_outer, length),
    (r_counterbore, length),
    (r_counterbore, length - cb),
    (r_bore, length - cb),
    (r_bore, cb),
    (r_counterbore, cb),
    (r_counterbore, 0.0),
  ]
  let body = @cad.RevolvedProfile::polyline(points.rev(), closed=true).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["body", "bore", "outer-retaining-grooves", "end-counterbores"],
    omitted=[
      @common.Omission::new(
        feature="rolling-elements",
        reason="the LM envelope has no ball complement or cage",
      ),
      @common.Omission::new(feature="seals", reason="seals are not modelled"),
      @common.Omission::new(
        feature="ball-return-grooves",
        reason="internal recirculation geometry is not modelled",
      ),
      @common.Omission::new(
        feature="mounting-holes",
        reason="LM bushings are pressed or clamped, not bolted",
      ),
    ],
  )
  let component = @common.Component::new(
    name=size.designation,
    metadata=@common.Metadata::new(
      designation="\{size.designation} linear ball bushing",
      standard="LM-series catalogue boundary dimensions; envelope only",
      family="linear ball bushing",
      size=size.designation,
      length_mm=length,
      source="Boundary dimensions from LM-series catalogue data; groove and counterbore proportions are scaled from the step.parts LM8UU reference envelope.",
    ),
    description="LM-series linear ball-bushing envelope: outside diameter with end retaining grooves and a plain bore with end counterbores. Rolling elements, cage, seals, and recirculation grooves are omitted.",
    features~,
  ).add_layer(body, name="body", color~)
  if orient_to_reference {
    Ok(component.translate(z=-length / 2.0))
  } else {
    Ok(component)
  }
}

///|
/// linear_bearing_by_designation looks up a size and builds the bushing.
pub fn linear_bearing_by_designation(
  designation : String,
  detail~ : @common.DetailLevel = @common.DetailLevel::Detailed,
) -> Result[@common.Component, @common.SpecError] {
  match linear_bearing_size(designation) {
    Ok(size) => linear_bearing(size, detail~)
    Err(e) => Err(e)
  }
}

///|
/// flanged_linear_bearing builds a flanged round linear-bushing housing.
///
/// Geometry, axis +Z with the flange back face at `z = 0`:
/// - a circular flange of `flange_diameter_mm` and `flange_thickness_mm`;
/// - a cylindrical body of the bushing's outside diameter and length;
/// - a through bore of the bushing bore diameter.
///
/// The flange defaults scale from the LM8UU reference envelope. The housing is
/// a single solid; mounting holes, seals, and rolling elements are omitted.
pub fn flanged_linear_bearing(
  size : LinearBearingSize,
  flange_diameter_mm? : Double,
  flange_thickness_mm? : Double,
  orient_to_reference~ : Bool = false,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let r_bore = size.bore_mm / 2.0
  let r_outer = size.outer_mm / 2.0
  let flange_diameter = match flange_diameter_mm {
    Some(v) => v
    None => 1.65 * size.outer_mm
  }
  let flange_thickness = match flange_thickness_mm {
    Some(v) => v
    None => 0.1125 * size.length_mm
  }
  match @common.require_positive("flange diameter", flange_diameter) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("flange thickness", flange_thickness) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let r_flange = flange_diameter / 2.0
  if r_flange <= r_outer {
    return Err(
      @common.InvalidDimension(
        "flange diameter must exceed the housing diameter",
      ),
    )
  }
  if r_outer <= r_bore {
    return Err(
      @common.InvalidDimension("housing outside diameter must exceed the bore"),
    )
  }
  let body_length = size.length_mm
  let total = flange_thickness + body_length
  let points : Array[@cad.Vec2] = [
    (r_bore, 0.0),
    (r_flange, 0.0),
    (r_flange, flange_thickness),
    (r_outer, flange_thickness),
    (r_outer, total),
    (r_bore, total),
  ]
  let body = @cad.RevolvedProfile::polyline(points, closed=true).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["body", "flange", "bore"],
    omitted=[
      @common.Omission::new(
        feature="mounting-holes",
        reason="flange hole patterns vary by manufacturer; none is asserted",
      ),
      @common.Omission::new(
        feature="rolling-elements",
        reason="the housing envelope has no ball complement",
      ),
      @common.Omission::new(feature="seals", reason="seals are not modelled"),
    ],
  )
  let name = "FL-\{size.designation}"
  let component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Flanged \{size.designation} linear bushing housing",
      standard="LM-series boundary dimensions with a round flange; envelope only",
      family="flanged linear bushing housing",
      size=size.designation,
      length_mm=total,
      source="Bore and body diameter from the LM-series size table; flange diameter and thickness default from the step.parts LM8UU flanged-round reference envelope.",
    ),
    description="Flanged round linear-bushing housing: one flange, a body, and a through bore. Mounting holes, seals, and rolling elements are omitted.",
    features~,
  ).add_layer(body, name="body", color~)
  if orient_to_reference {
    Ok(
      component
      .rotate_y(90.0)
      .translate(x=-(flange_thickness + body_length / 2.0)),
    )
  } else {
    Ok(component)
  }
}
