///|
/// PlateHole is one circular through hole in a plate, in the plate's local
/// XY coordinates.
pub(all) struct PlateHole {
  x_mm : Double
  y_mm : Double
  diameter_mm : Double
}

///|
/// plate builds a rectangular flat plate with optional circular through holes.
///
/// Geometry: the plate is centered on the XY origin and on `z = 0`, with its
/// faces at `z = +/- thickness / 2`. This matches the common plate-blank
/// reference frame. Holes are through holes in the +Z direction.
///
/// The plate is a generic blank: it does not imply a standardized commercial
/// part, and hole patterns are the caller's responsibility.
pub fn plate(
  width_mm : Double,
  height_mm : Double,
  thickness_mm : Double,
  holes~ : Array[PlateHole] = [],
  detail~ : @common.DetailLevel = @common.DetailLevel::Detailed,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("plate width", width_mm),
    @common.require_positive("plate height", height_mm),
    @common.require_positive("plate thickness", thickness_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let policy = @common.DetailPolicy::for_level(detail)
  let segments = if policy.circle_segments < 32 {
    32
  } else {
    policy.circle_segments
  }
  for i, hole in holes {
    match @common.require_positive("plate hole diameter", hole.diameter_mm) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    if hole.diameter_mm / 2.0 >= width_mm / 2.0 ||
      hole.diameter_mm / 2.0 >= height_mm / 2.0 {
      return Err(
        @common.InvalidDimension(
          "plate hole \{i} diameter does not fit the plate",
        ),
      )
    }
    let radius = hole.diameter_mm / 2.0
    if hole.x_mm - radius < -width_mm / 2.0 ||
      hole.x_mm + radius > width_mm / 2.0 ||
      hole.y_mm - radius < -height_mm / 2.0 ||
      hole.y_mm + radius > height_mm / 2.0 {
      return Err(
        @common.InvalidDimension(
          "plate hole \{i} lies outside the plate boundary",
        ),
      )
    }
    for j, other in holes {
      if j <= i {
        continue
      }
      let dx = hole.x_mm - other.x_mm
      let dy = hole.y_mm - other.y_mm
      let distance = (dx * dx + dy * dy).sqrt()
      if distance < (hole.diameter_mm + other.diameter_mm) / 2.0 {
        return Err(
          @common.InvalidParameter("plate holes \{i} and \{j} overlap"),
        )
      }
    }
  }
  let outer = @cad.Profile2D::centered_rect(width_mm, height_mm)
  let hole_profiles = holes.map(fn(hole) {
    let circle = @cad.Profile2D::circle(hole.diameter_mm, segments~).rev()
    @cad.translate_pts(circle, hole.x_mm, hole.y_mm)
  })
  let body = @cad.ExtrudedProfile::new(outer, thickness_mm, holes=hole_profiles)
  let features = @common.FeatureRecord::new(
    modeled=["body", "through-holes"],
    approximated=holes.map(fn(hole) {
      @common.Approximation::new(
        feature="through-hole",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=@common.chord_deviation(hole.diameter_mm / 2.0, segments),
        control="circle_segments=\{segments}",
      )
    }),
    omitted=[
      @common.Omission::new(
        feature="edge-chamfers",
        reason="no edge treatment is asserted",
      ),
      @common.Omission::new(
        feature="material-and-tolerances",
        reason="the plate is a nominal geometric blank",
      ),
    ],
  )
  let name = "plate-\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(height_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}"
  let component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Plate \{@cad.fmt_double(width_mm, None)} x \{@cad.fmt_double(height_mm, None)} x \{@cad.fmt_double(thickness_mm, None)}",
      family="flat plate blank",
      size="\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(height_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}",
      source="Parametric rectangular plate centered on the origin; hole patterns are caller-supplied.",
    ),
    description="Rectangular flat plate blank centered on the XY origin with optional circular through holes. No edge treatment or material tolerance is asserted.",
    features~,
  ).add_layer(body, name="body", color~)
  Ok(
    with_plate_connectors(
      component.translate(z=-thickness_mm / 2.0),
      width_mm,
      height_mm,
      thickness_mm,
      holes,
    ),
  )
}
