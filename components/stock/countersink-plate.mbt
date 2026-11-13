///|
/// CountersunkHole is one countersunk (conical-seat) through hole in a plate,
/// in the plate's local XY coordinates. The countersink opens on the top (+Z)
/// face.
pub(all) struct CountersunkHole {
  x_mm : Double
  y_mm : Double
  through_diameter_mm : Double
  countersink_diameter_mm : Double
  countersink_depth_mm : Double
}

///|
/// countersink_ring returns the annular conical wedge between the countersink
/// cone and the countersink-diameter cylinder, as an exact solid of revolution.
///
/// The (r, z) triangle is `(rc, depth), (rc, 0), (rt, 0)`: the vertical edge is
/// the countersink-diameter cylinder, the base is the annular shoulder, and the
/// hypotenuse is the conical seat. Revolving it produces the material that a
/// prismatic extrusion cannot express, so the countersink is a real conical
/// surface rather than a stepped approximation.
fn countersink_ring(
  rc : Double,
  rt : Double,
  depth : Double,
) -> @cad.RevolvedProfile {
  @cad.RevolvedProfile::polyline(
    [(rc, depth), (rc, 0.0), (rt, 0.0)],
    closed=true,
  )
}

///|
/// plate_with_countersinks builds a rectangular plate with countersunk through
/// holes.
///
/// Frame: the plate is centred on the XY origin with faces at
/// `z = +/- thickness/2`, matching `plate`. Each hole is a countersunk bore: a
/// through hole at `through_diameter_mm` plus a conical seat that opens from
/// `countersink_diameter_mm` at the top (+Z) face to the through diameter at
/// `countersink_depth_mm` below it.
///
/// Construction is layered and exact: a full-width lower layer carrying the
/// through holes, a countersink-depth upper layer carrying the larger
/// countersink-diameter holes, and one annular conical wedge per hole whose
/// outer face closes the upper layer and whose conical face is the seat. The
/// layers touch face-to-face or cylinder-to-cylinder and do not overlap, so the
/// component volume is the exact sum of the layer volumes. The seat is a true
/// `CONICAL_SURFACE`.
///
/// A countersink is not a prismatic cut. This builder is the honest additive
/// decomposition of that cut; it is not a boolean. The included angle is
/// whatever the caller's diameter and depth imply (a 90 degree included
/// countersink needs `countersink_depth = (countersink_diameter -
/// through_diameter) / 2`).
pub fn plate_with_countersinks(
  width_mm : Double,
  height_mm : Double,
  thickness_mm : Double,
  holes~ : Array[CountersunkHole],
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("countersunk plate width", width_mm),
    @common.require_positive("countersunk plate height", height_mm),
    @common.require_positive("countersunk plate thickness", thickness_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if holes.length() == 0 {
    return Err(
      @common.InvalidParameter(
        "countersunk plate needs at least one hole; use plate for a blank",
      ),
    )
  }
  for i, hole in holes {
    match
      @common.require_positive(
        "countersunk hole through diameter \{i + 1}",
        hole.through_diameter_mm,
      ) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    if hole.countersink_diameter_mm <= hole.through_diameter_mm {
      return Err(
        @common.InvalidParameter(
          "countersink \{i + 1} must be larger than its through hole",
        ),
      )
    }
    match
      @common.require_positive(
        "countersunk hole depth \{i + 1}",
        hole.countersink_depth_mm,
      ) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    if hole.countersink_depth_mm >= thickness_mm {
      return Err(
        @common.InvalidDimension(
          "countersink \{i + 1} depth reaches through the plate",
        ),
      )
    }
    let r = hole.countersink_diameter_mm / 2.0
    if hole.x_mm - r < -width_mm / 2.0 ||
      hole.x_mm + r > width_mm / 2.0 ||
      hole.y_mm - r < -height_mm / 2.0 ||
      hole.y_mm + r > height_mm / 2.0 {
      return Err(
        @common.InvalidDimension(
          "countersink \{i + 1} lies outside the plate boundary",
        ),
      )
    }
    for j, other in holes {
      if j <= i {
        continue
      }
      let dx = hole.x_mm - other.x_mm
      let dy = hole.y_mm - other.y_mm
      let rr = hole.countersink_diameter_mm / 2.0 +
        other.countersink_diameter_mm / 2.0
      if (dx * dx + dy * dy).sqrt() < rr {
        return Err(
          @common.InvalidParameter("countersinks \{i + 1} and \{j + 1} overlap"),
        )
      }
    }
  }
  let depth = holes[0].countersink_depth_mm
  for hole in holes {
    if (hole.countersink_depth_mm - depth).abs() > 1.0e-9 {
      return Err(
        @common.InvalidParameter(
          "countersunk plate requires one common countersink depth",
        ),
      )
    }
  }
  let lower_thickness = thickness_mm - depth
  let through_loops = holes.map(fn(hole) {
    plate_circle_loop(hole.x_mm, hole.y_mm, hole.through_diameter_mm / 2.0)
  })
  let countersink_loops = holes.map(fn(hole) {
    plate_circle_loop(hole.x_mm, hole.y_mm, hole.countersink_diameter_mm / 2.0)
  })
  let outer = plate_rect_loop(width_mm, height_mm)
  let lower = @cad.ExtrudedArcProfile::new(
    outer,
    lower_thickness,
    holes=through_loops,
  ).as_shape()
  let upper = @cad.ExtrudedArcProfile::new(
    outer,
    depth,
    holes=countersink_loops,
  ).as_shape()
  let half = thickness_mm / 2.0
  let face_size = if width_mm < height_mm { width_mm } else { height_mm }
  let mut component = @common.Component::new(
      name="plate-countersink-\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(height_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}",
      metadata=@common.Metadata::new(
        designation="Countersunk plate \{@cad.fmt_double(width_mm, None)} x \{@cad.fmt_double(height_mm, None)} x \{@cad.fmt_double(thickness_mm, None)}",
        family="countersunk plate",
        size="\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(height_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}",
        source="Parametric countersunk plate: conical seats are exact annular wedges of revolution added over a stepped through-hole layer; hole positions are caller-supplied.",
      ),
      description="Rectangular plate with countersunk through holes. A conical seat is a solid of revolution layered between a stepped bore and the countersink-diameter layer; no boolean is used. Hole positions are caller-supplied.",
      features=@common.FeatureRecord::new(
        modeled=["body", "through-holes", "conical-countersinks"],
        approximated=[],
        omitted=[
          @common.Omission::new(
            feature="hole-positions-and-angle",
            reason="the included countersink angle is implied by the caller's diameter and depth; no standard angle is asserted",
          ),
          @common.Omission::new(
            feature="edge-chamfer",
            reason="not modelled by this builder",
          ),
        ],
      ),
    )
    .add_layer(
      lower,
      name="body-lower",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, -half),
    )
    .add_layer(
      upper,
      name="body-upper",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, half - depth),
    )
  for i, hole in holes {
    let ring = countersink_ring(
      hole.countersink_diameter_mm / 2.0,
      hole.through_diameter_mm / 2.0,
      depth,
    )
    component = component.add_layer(
      ring.as_shape(),
      name="countersink-\{i + 1}",
      color~,
      placement=@common.Placement::translation(
        hole.x_mm,
        hole.y_mm,
        half - depth,
      ),
    )
  }
  component = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-top",
        placement=@common.Placement::translation(0.0, 0.0, half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=face_size,
        description="top face; outward normal is +Z and the countersinks open here",
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
  for i, hole in holes {
    component = component
      .with_connector_unchecked(
        @common.MateConnector::new(
          "hole-\{i + 1}",
          placement=@common.Placement::translation(hole.x_mm, hole.y_mm, -half),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=hole.through_diameter_mm,
          depth_mm=thickness_mm,
          description="through hole; the countersink opens on the +Z face",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "countersink-\{i + 1}",
          placement=@common.Placement::translation(hole.x_mm, hole.y_mm, half),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=hole.countersink_diameter_mm,
          depth_mm=hole.countersink_depth_mm,
          description="conical seat; entered from the +Z face, entry diameter is the countersink diameter",
        ),
      )
  }
  Ok(component)
}
