///|
/// iso2338_pin builds an ISO 2338 parallel dowel pin: one analytic cylinder
/// with 45-degree conical end breaks, centred on the origin.
pub fn iso2338_pin(
  size : @standards.MetricSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
  color~ : @cad.Rgb = @cad.Rgb::orange(),
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  let dims = match @standards.iso2338_size(size) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  if length_mm < dims.min_length_mm - 1.0e-9 ||
    length_mm > dims.max_length_mm + 1.0e-9 {
    return Err(
      @common.SpecError::UnsupportedLength(
        "ISO 2338 \{size.designation()}: length \{length_mm} is outside \{dims.min_length_mm}..\{dims.max_length_mm}",
      ),
    )
  }
  let r = dims.diameter_mm / 2.0
  let c = dims.chamfer_mm
  if c <= 0.0 || c >= r {
    return Err(
      @common.SpecError::InvalidDimension(
        "ISO 2338 chamfer must be below the pin radius",
      ),
    )
  }
  let z0 = -length_mm / 2.0
  let z1 = length_mm / 2.0
  let pts : Array[@cad.Vec2] = [
    (0.0, z0),
    (r - c, z0),
    (r, z0 + c),
    (r, z1 - c),
    (r - c, z1),
    (0.0, z1),
  ]
  let body = @cad.RevolvedProfile::polyline(pts)
  let features = @common.FeatureRecord::new(
    modeled=["body", "outer-cylinder", "end-chamfers"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="tolerance-class",
        reason="nominal geometry only; no h/g tolerance class",
      ),
    ],
  )
  Ok(
    with_pin_connectors(
      @common.Component::new(
        name="ISO2338-\{size.designation()}x\{length_mm}",
        metadata=@standards.iso2338_metadata(dims, length_mm),
        description="Parallel dowel pin: one closed solid of revolution, a cylinder with 45-degree conical end breaks; the nominal diameter follows ISO 2338 and the chamfer is the reference 0.08 d, retained at every detail level.",
        features~,
      ).add_layer(body.as_shape(), name="body", color~),
      dims.diameter_mm,
      length_mm,
    ),
  )
}
