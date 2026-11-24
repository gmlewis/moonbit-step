///|
/// gobilda_rect_loop returns a counter-clockwise rectangular outer loop
/// centred on the origin.
fn gobilda_rect_loop(
  width_mm : Double,
  height_mm : Double,
) -> Array[@cad.ProfileSegment] {
  let hw = width_mm / 2.0
  let hh = height_mm / 2.0
  [
    @cad.SegmentLine((-hw, -hh), (hw, -hh)),
    @cad.SegmentLine((hw, -hh), (hw, hh)),
    @cad.SegmentLine((hw, hh), (-hw, hh)),
    @cad.SegmentLine((-hw, hh), (-hw, -hh)),
  ]
}

///|
/// gobilda_grid_plate builds a goBILDA grid plate: a rectangular aluminium plate
/// with a full grid of 4 mm through holes on the 8 mm pattern.
///
/// A plate named `cols x rows` is `cols * 8` by `rows * 8` mm with one half-pitch
/// (4 mm) margin around the hole grid, so 5 x 5 = 40 x 40 mm and 11 x 29 =
/// 88 x 232 mm, matching the goBILDA 1116 Series Grid Plate Bundle. The plate is
/// centred on the XY origin and on `z = 0`; every hole is a true analytic
/// cylinder. The default 2.5 mm aluminium sheet thickness matches the structural
/// grid plates.
///
/// Source: https://www.gobilda.com/grid-plates and https://www.gobilda.com/pattern.
pub fn gobilda_grid_plate(
  cols~ : Int32 = 5,
  rows~ : Int32 = 5,
  thickness_mm~ : Double = gobilda_sheet_thickness_mm,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  if cols < 1 || rows < 1 {
    return Err(
      @common.InvalidParameter(
        "goBILDA grid plate needs at least one hole per axis",
      ),
    )
  }
  match @common.require_positive("goBILDA grid plate thickness", thickness_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let width = cols.to_double() * gobilda_grid_mm
  let height = rows.to_double() * gobilda_grid_mm
  let xs = gobilda_grid_positions(cols)
  let ys = gobilda_grid_positions(rows)
  let radius = gobilda_hole_diameter_mm / 2.0
  let holes : Array[Array[@cad.ProfileSegment]] = []
  for x in xs {
    for y in ys {
      holes.push(@common.circle_loop(x, y, radius))
    }
  }
  let body = @cad.ExtrudedArcProfile::new(
    gobilda_rect_loop(width, height),
    thickness_mm,
    holes~,
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["body", "through-holes"],
    approximated=[],
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
  let size = "\{cols}x\{rows}"
  let name = "gobilda-grid-plate-\{size}"
  let component = @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="goBILDA Grid Plate \{size} (\{@cad.fmt_double(width, None)} x \{@cad.fmt_double(height, None)} x \{@cad.fmt_double(thickness_mm, None)})",
        standard="goBILDA 8 mm pattern",
        family="goBILDA grid plate",
        size~,
        source="https://www.gobilda.com/grid-plates | goBILDA 8 mm pattern: 4 mm holes on an 8 mm grid | aluminium, clear anodized, 2.5 mm | sizes match the 1116 Series Grid Plate Bundle",
      ),
      description="goBILDA grid plate with a full 4 mm hole grid on the 8 mm pattern. Holes are exact analytic cylinders; edge chamfers and material tolerances are omitted.",
      features~,
    )
    .add_layer(body, name="body", color~)
    .translate(z=-thickness_mm / 2.0)
  let half = thickness_mm / 2.0
  let face_size = if width < height { width } else { height }
  let mut out = component
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
  let mut index = 0
  for x in xs {
    for y in ys {
      index += 1
      out = out.with_connector_unchecked(
        @common.MateConnector::new(
          "hole-\{index}",
          placement=@common.Placement::translation(x, y, -half),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=gobilda_hole_diameter_mm,
          depth_mm=thickness_mm,
          description="4 mm through hole on the goBILDA 8 mm pattern",
        ),
      )
    }
  }
  Ok(out)
}

///|
/// gobilda_grid_plate_family exposes the goBILDA grid plate as a validated design
/// family with one preset per size in the 1116 Series bundle.
pub fn gobilda_grid_plate_family() -> Result[
  @common.DesignFamily,
  @common.SpecError,
] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="cols",
      default_mm=5.0,
      min_mm=2.0,
      max_mm=12.0,
      unit="count",
      description="hole columns along X",
    ),
    @common.ParamSpec::new(
      name="rows",
      default_mm=5.0,
      min_mm=2.0,
      max_mm=30.0,
      unit="count",
      description="hole rows along Y",
    ),
    @common.ParamSpec::new(
      name="thickness",
      default_mm=gobilda_sheet_thickness_mm,
      min_mm=1.0,
      max_mm=6.0,
      description="plate thickness",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="gobilda-grid-plate",
      specs~,
      description="goBILDA grid plate: 4 mm holes on an 8 mm grid.",
      build=fn(parameters) {
        let cols = match parameters.get("cols") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let rows = match parameters.get("rows") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let thickness = match parameters.get("thickness") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        gobilda_grid_plate(
          cols=cols.to_int(),
          rows=rows.to_int(),
          thickness_mm=thickness,
        )
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let sizes : Array[(String, Double, Double)] = [
    ("3x5", 3.0, 5.0),
    ("5x5", 5.0, 5.0),
    ("5x7", 5.0, 7.0),
    ("5x9", 5.0, 9.0),
    ("5x11", 5.0, 11.0),
    ("5x17", 5.0, 17.0),
    ("7x7", 7.0, 7.0),
    ("7x11", 7.0, 11.0),
    ("11x29", 11.0, 29.0),
  ]
  let mut out = family
  for entry in sizes {
    let (variant, cols, rows) = entry
    out = match out.with_variant(variant, [("cols", cols), ("rows", rows)]) {
      Ok(f) => f
      Err(e) => return Err(e)
    }
  }
  Ok(out)
}
