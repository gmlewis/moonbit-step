///|
/// EmtSize carries the boundary dimensions of one trade size of electrical
/// metallic tubing (EMT).
///
/// Trade size is **not** the measured outside diameter: a 1/2 in EMT has a
/// 0.706 in (17.93 mm) outside diameter. Values follow ANSI C80.3 / UL 797 as
/// tabulated by several manufacturer catalogues. Wall thickness is nominal.
pub(all) struct EmtSize {
  trade_size : String
  outside_diameter_mm : Double
  wall_mm : Double
}

///|
/// EmtSize::inside_diameter_mm returns `OD - 2 * wall`.
fn EmtSize::inside_diameter_mm(self : EmtSize) -> Double {
  self.outside_diameter_mm - 2.0 * self.wall_mm
}

///|
/// emt_size looks up a standard EMT trade size.
///
/// The table is boundary data for plain tubing only. No pipe thread, bend,
/// coupling, or structural rating is implied.
pub fn emt_size(trade_size : String) -> Result[EmtSize, @common.SpecError] {
  let (od, wall) = match trade_size {
    // Inch dimensions converted exactly: OD x 25.4, wall x 25.4.
    "1/2" => (17.9324, 1.0668)
    "3/4" => (23.4188, 1.2446)
    "1" => (29.5402, 1.4478)
    "1-1/4" => (38.354, 1.651)
    "1-1/2" => (44.196, 1.651)
    "2" => (55.8038, 1.651)
    other =>
      return Err(
        @common.InvalidSize(
          "unsupported EMT trade size: \{other}; supported: 1/2, 3/4, 1, 1-1/4, 1-1/2, 2",
        ),
      )
  }
  Ok({ trade_size, outside_diameter_mm: od, wall_mm: wall, })
}

///|
/// emt_trade_sizes returns every supported EMT trade size.
pub fn emt_trade_sizes() -> Array[String] {
  ["1/2", "3/4", "1", "1-1/4", "1-1/2", "2"]
}

///|
/// emt_tube builds a plain cut length of EMT as one analytic annular solid of
/// revolution.
///
/// Axis +Z, from `z = 0` to `z = length`. The outside and inside diameters are
/// true cylinders; no coupling, thread, bend, or end burr is modelled. This is
/// a geometric primitive: it makes no claim about wall strength, conduit fill,
/// or electrical suitability.
pub fn emt_tube(
  size : EmtSize,
  length_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("EMT length", length_mm) {
    Err(e) => Err(e)
    Ok(_) => {
      let id = size.inside_diameter_mm()
      let body = @cad.RevolvedProfile::tube(
        size.outside_diameter_mm,
        id,
        length_mm,
      ).as_shape()
      let features = @common.FeatureRecord::new(
        modeled=["body", "outside-cylinder", "inside-cylinder"],
        approximated=[],
        omitted=[
          @common.Omission::new(
            feature="thread-and-fittings",
            reason="EMT is coupled with separate fittings; no thread or coupling is modelled",
          ),
          @common.Omission::new(
            feature="structural-rating",
            reason="geometry alone does not establish strength, conduit fill, or electrical suitability",
          ),
        ],
      )
      Ok(
        with_emt_connectors(
          @common.Component::new(
            name="emt-\{size.trade_size}-\{@cad.fmt_double(length_mm, None)}",
            metadata=@common.Metadata::new(
              designation="EMT conduit \{size.trade_size} in x \{@cad.fmt_double(length_mm, None)}",
              standard="ANSI C80.3 / UL 797 EMT boundary dimensions",
              family="electrical metallic tubing",
              size=size.trade_size,
              length_mm~,
              source="ANSI C80.3 / UL 797 EMT table: OD \{@cad.fmt_double(size.outside_diameter_mm, None)} mm, nominal wall \{@cad.fmt_double(size.wall_mm, None)} mm.",
            ),
            description="Plain cut-length EMT tube with analytic outside and inside cylinders. No coupling, thread, bend, or structural rating is modelled.",
            features~,
          ).add_layer(body, name="body", color~),
          size,
          length_mm,
        ),
      )
    }
  }
}

///|
/// with_emt_connectors attaches both end bores, both outer ends, and the two
/// end faces.
fn with_emt_connectors(
  component : @common.Component,
  size : EmtSize,
  length_mm : Double,
) -> @common.Component {
  let id = size.inside_diameter_mm()
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "bore-a",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=id,
      depth_mm=length_mm,
      description="inside diameter, entered from the z = 0 end",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "bore-b",
      placement=@common.Placement::translation(0.0, 0.0, length_mm),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=id,
      depth_mm=length_mm,
      description="inside diameter, entered from the z = length end",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "outer-a",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=size.outside_diameter_mm,
      depth_mm=length_mm,
      description="outside diameter, entered from the z = 0 end",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "outer-b",
      placement=@common.Placement::translation(0.0, 0.0, length_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=size.outside_diameter_mm,
      depth_mm=length_mm,
      description="outside diameter, entered from the z = length end",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "end-a",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=size.outside_diameter_mm,
      description="square-cut end at z = 0",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "end-b",
      placement=@common.Placement::translation(0.0, 0.0, length_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=size.outside_diameter_mm,
      description="square-cut end at z = length",
    ),
  )
}
