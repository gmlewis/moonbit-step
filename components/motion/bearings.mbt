///|
/// BearingSize carries the boundary dimensions of a standard radial ball
/// bearing: bore `d`, outside diameter `D`, and width `B`.
///
/// The table covers common ISO 15 / catalogue sizes. It is boundary data only;
/// internal ring and ball geometry is parametric and simplified.
pub(all) struct BearingSize {
  designation : String
  bore_mm : Double
  outer_mm : Double
  width_mm : Double
}

///|
/// bearing_size looks up a bearing by its catalogue designation.
pub fn bearing_size(
  designation : String,
) -> Result[BearingSize, @common.SpecError] {
  let (d, outer, width) = match designation {
    "608" => (8.0, 22.0, 7.0)
    "6000" => (10.0, 26.0, 8.0)
    "6001" => (12.0, 28.0, 8.0)
    "6002" => (15.0, 32.0, 9.0)
    "6003" => (17.0, 35.0, 10.0)
    "6004" => (20.0, 42.0, 12.0)
    "6005" => (25.0, 47.0, 12.0)
    "6006" => (30.0, 55.0, 13.0)
    "6200" => (10.0, 30.0, 9.0)
    "6201" => (12.0, 32.0, 10.0)
    "6202" => (15.0, 35.0, 11.0)
    "6203" => (17.0, 40.0, 12.0)
    "6204" => (20.0, 47.0, 14.0)
    "6205" => (25.0, 52.0, 15.0)
    "6206" => (30.0, 62.0, 16.0)
    "6300" => (10.0, 35.0, 11.0)
    "6301" => (12.0, 37.0, 12.0)
    "6302" => (15.0, 42.0, 13.0)
    "6303" => (17.0, 47.0, 14.0)
    "6304" => (20.0, 52.0, 15.0)
    "6305" => (25.0, 62.0, 17.0)
    other =>
      return Err(
        @common.InvalidSize(
          "unsupported bearing designation: \{other}; supported: 608, 6000-6006, 6200-6206, 6300-6305",
        ),
      )
  }
  Ok({ designation, bore_mm: d, outer_mm: outer, width_mm: width, })
}

///|
/// bearing_designations returns every supported bearing designation.
pub fn bearing_designations() -> Array[String] {
  [
    "608", "6000", "6001", "6002", "6003", "6004", "6005", "6006", "6200", "6201",
    "6202", "6203", "6204", "6205", "6206", "6300", "6301", "6302", "6303", "6304",
    "6305",
  ]
}

///|
/// bearing builds a simplified radial bearing envelope.
///
/// Geometry: an outer ring, an inner ring, and a set of cylindrical roller
/// proxies between them. **Balls are not modeled as spheres**: the rolling
/// elements are cylinders with diameter and length equal to the radial gap.
/// This is an assembly envelope, not an exact catalogue bearing. Ring
/// dimensions are derived as `(D - d) / 5` unless `ring_thickness_mm` is given.
///
/// Axis +Z, base at z = 0.
pub fn bearing(
  size : BearingSize,
  ring_thickness_mm? : Double,
  roller_count~ : Int32 = 8,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  let d = size.bore_mm
  let outer = size.outer_mm
  let width = size.width_mm
  let ring_t = match ring_thickness_mm {
    Some(v) => v
    None => (outer - d) / 5.0
  }
  match @common.require_positive("bearing ring thickness", ring_t) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if ring_t * 2.0 >= outer - d {
    return Err(
      @common.InvalidDimension("bearing ring thickness leaves no radial gap"),
    )
  }
  if roller_count < 1 {
    return Err(
      @common.InvalidParameter("bearing roller count must be at least 1"),
    )
  }
  let gap = outer - d - 4.0 * ring_t
  if gap <= 0.0 {
    return Err(
      @common.InvalidDimension(
        "bearing radial gap must be positive; reduce the ring thickness",
      ),
    )
  }
  let policy = @common.DetailPolicy::for_level(detail)
  let segments = if policy.circle_segments < 32 {
    32
  } else {
    policy.circle_segments
  }
  let base_color = match color {
    Some(c) => c
    None => @cad.Rgb::purple()
  }
  let name = "bearing-\{size.designation}"
  let mut component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Bearing \{size.designation}",
      standard="ISO 15 boundary dimensions; simplified internal geometry",
      family="radial ball bearing (simplified envelope)",
      size=size.designation,
      source="Boundary dimensions from common ISO 15 / catalogue tables; internal rings and rollers are parametric, not catalogue geometry. See components/DATA_SOURCES.md.",
    ),
    description="Outer and inner rings plus cylindrical roller proxies. Balls are not modeled as spheres. Rings are plain tubes; seals, cages, and chamfers are omitted.",
  )
  component = component.add_layer(
    @cad.tube(outer, outer - 2.0 * ring_t, width, segments~),
    name="outer-ring",
    color=base_color,
  )
  component = component.add_layer(
    @cad.tube(d + 2.0 * ring_t, d, width, segments~),
    name="inner-ring",
    color=@cad.Rgb::blue(),
  )
  let mid_radius = (outer + d) / 4.0
  for i in 0..<roller_count {
    let angle = 360.0 * i.to_double() / roller_count.to_double()
    let base = @common.Placement::at(
      mid_radius - gap / 2.0,
      0.0,
      width / 2.0,
      ry=90.0,
    )
    let placement = @common.Placement::compose(
      @common.Placement::rotation_z(angle),
      base,
    )
    component = component.add_layer(
      @cad.Cylinder::new(gap, gap),
      name="roller-\{i + 1}",
      color=@cad.Rgb::orange(),
      placement~,
    )
  }
  Ok(component)
}

///|
/// bearing_by_designation looks up a bearing by name and builds it.
pub fn bearing_by_designation(
  designation : String,
  detail~ : @common.DetailLevel = Simplified,
) -> Result[@common.Component, @common.SpecError] {
  match bearing_size(designation) {
    Err(e) => Err(e)
    Ok(size) => bearing(size, detail~)
  }
}
