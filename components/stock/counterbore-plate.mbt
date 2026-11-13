///|
/// CounterboredHole is one counterbored through hole in a plate, in the plate's
/// local XY coordinates. The counterbore opens on the top (+Z) face.
pub(all) struct CounterboredHole {
  x_mm : Double
  y_mm : Double
  through_diameter_mm : Double
  counterbore_diameter_mm : Double
  counterbore_depth_mm : Double
}

///|
/// plate_with_counterbores builds a rectangular plate with counterbored
/// through holes.
///
/// Frame: the plate is centred on the XY origin with faces at
/// `z = +/- thickness/2`, matching `plate`. Each hole is a stepped bore: a
/// through hole at `through_diameter_mm` plus a counterbore at
/// `counterbore_diameter_mm` and `counterbore_depth_mm` opening on the top
/// (+Z) face. The counterbore must be at least as large as the through hole.
///
/// Construction is layered: a full-thickness lower layer carrying the through
/// holes and a counterbore-depth upper layer carrying the larger counterbore
/// holes. The two layers touch face-to-face but do not overlap, so the
/// component volume is the exact sum of the layers. The counterbore is a real
/// stepped feature, not a flat annotation. Countersunk (conical) holes are not
/// modelled by this builder.
pub fn plate_with_counterbores(
  width_mm : Double,
  height_mm : Double,
  thickness_mm : Double,
  holes~ : Array[CounterboredHole],
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("counterbored plate width", width_mm),
    @common.require_positive("counterbored plate height", height_mm),
    @common.require_positive("counterbored plate thickness", thickness_mm),
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
        "counterbored plate needs at least one hole; use plate for a blank",
      ),
    )
  }
  for i, hole in holes {
    match
      @common.require_positive(
        "counterbored hole through diameter \{i + 1}",
        hole.through_diameter_mm,
      ) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    if hole.counterbore_diameter_mm < hole.through_diameter_mm {
      return Err(
        @common.InvalidParameter(
          "counterbore \{i + 1} is smaller than its through hole",
        ),
      )
    }
    match
      @common.require_positive(
        "counterbored hole depth \{i + 1}",
        hole.counterbore_depth_mm,
      ) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    if hole.counterbore_depth_mm >= thickness_mm {
      return Err(
        @common.InvalidDimension(
          "counterbore \{i + 1} depth reaches through the plate",
        ),
      )
    }
    let r = hole.counterbore_diameter_mm / 2.0
    if hole.x_mm - r < -width_mm / 2.0 ||
      hole.x_mm + r > width_mm / 2.0 ||
      hole.y_mm - r < -height_mm / 2.0 ||
      hole.y_mm + r > height_mm / 2.0 {
      return Err(
        @common.InvalidDimension(
          "counterbore \{i + 1} lies outside the plate boundary",
        ),
      )
    }
    for j, other in holes {
      if j <= i {
        continue
      }
      let dx = hole.x_mm - other.x_mm
      let dy = hole.y_mm - other.y_mm
      let rr = hole.counterbore_diameter_mm / 2.0 +
        other.counterbore_diameter_mm / 2.0
      if (dx * dx + dy * dy).sqrt() < rr {
        return Err(
          @common.InvalidParameter("counterbores \{i + 1} and \{j + 1} overlap"),
        )
      }
    }
  }
  let lower_thickness = thickness_mm - holes[0].counterbore_depth_mm
  // All holes must share one counterbore depth for a single stepped layer;
  // vary the upper layer per distinct depth is unnecessary for the common
  // pattern, so require a common depth.
  for hole in holes {
    if (hole.counterbore_depth_mm - holes[0].counterbore_depth_mm).abs() >
      1.0e-9 {
      return Err(
        @common.InvalidParameter(
          "counterbored plate requires one common counterbore depth",
        ),
      )
    }
  }
  let through_loops = holes.map(fn(hole) {
    plate_circle_loop(hole.x_mm, hole.y_mm, hole.through_diameter_mm / 2.0)
  })
  let counterbore_loops = holes.map(fn(hole) {
    plate_circle_loop(hole.x_mm, hole.y_mm, hole.counterbore_diameter_mm / 2.0)
  })
  let outer = plate_rect_loop(width_mm, height_mm)
  let lower = @cad.ExtrudedArcProfile::new(
    outer,
    lower_thickness,
    holes=through_loops,
  ).as_shape()
  let upper = @cad.ExtrudedArcProfile::new(
    outer,
    holes[0].counterbore_depth_mm,
    holes=counterbore_loops,
  ).as_shape()
  let half = thickness_mm / 2.0
  let lower_placement = @common.Placement::translation(0.0, 0.0, -half)
  let upper_placement = @common.Placement::translation(
    0.0,
    0.0,
    half - holes[0].counterbore_depth_mm,
  )
  let face_size = if width_mm < height_mm { width_mm } else { height_mm }
  let mut component = @common.Component::new(
      name="plate-counterbore-\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(height_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}",
      metadata=@common.Metadata::new(
        designation="Counterbored plate \{@cad.fmt_double(width_mm, None)} x \{@cad.fmt_double(height_mm, None)} x \{@cad.fmt_double(thickness_mm, None)}",
        family="counterbored plate",
        size="\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(height_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}",
        source="Parametric counterbored plate: a through hole plus a cylindrical counterbore on the top face. Hole positions are caller-supplied; no standard pattern is implied.",
      ),
      description="Rectangular plate with counterbored through holes. Two touching layers form the stepped bore; no countersink, edge treatment, or material tolerance is asserted.",
      features=@common.FeatureRecord::new(
        modeled=["body", "through-holes", "counterbores"],
        omitted=[
          @common.Omission::new(
            feature="countersink",
            reason="this builder makes cylindrical counterbores only; conical countersinks are not modelled",
          ),
          @common.Omission::new(
            feature="edge-chamfer",
            reason="not modelled by this builder",
          ),
        ],
      ),
    )
    .add_layer(lower, name="body-lower", color~, placement=lower_placement)
    .add_layer(upper, name="body-upper", color~, placement=upper_placement)
  component = component
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
          description="through hole; the counterbore opens on the +Z face",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "counterbore-\{i + 1}",
          placement=@common.Placement::translation(
            hole.x_mm,
            hole.y_mm,
            half - hole.counterbore_depth_mm,
          ),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=hole.counterbore_diameter_mm,
          depth_mm=hole.counterbore_depth_mm,
          description="counterbore; entered from the +Z face",
        ),
      )
  }
  Ok(component)
}
