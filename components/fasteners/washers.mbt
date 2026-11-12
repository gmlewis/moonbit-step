///|
/// plain_washer builds a plain washer as one analytic annular solid of
/// revolution: two cylindrical surfaces and two planar faces, never a polygon.
fn plain_washer(
  name : String,
  metadata : @common.Metadata,
  inner_diameter_mm : Double,
  outer_diameter_mm : Double,
  thickness_mm : Double,
  standard_label : String,
  detail : @common.DetailLevel,
  color? : @cad.Rgb,
) -> @common.Component {
  let metal = match color {
    Some(c) => c
    None => @cad.Rgb::green()
  }
  let body = @cad.RevolvedProfile::tube(
    outer_diameter_mm, inner_diameter_mm, thickness_mm,
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["body", "outer-cylinder", "through-bore"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="edge-chamfer",
        reason=standard_label +
          " does not specify an edge chamfer or deburr; the sharp edge is the standard-correct representation",
      ),
    ],
  )
  @common.Component::new(
    name~,
    metadata~,
    description="Plain washer, normal series; a single extrusion with a circular bore. " +
      standard_label +
      " specifies no edge chamfer, so the sharp edge is modeled at every detail level and no chamfer is claimed." +
      edge_chamfer_note(detail, standard_label),
    features~,
  ).add_layer(body, name="body", color=metal)
}

///|
/// flat_washer builds an ISO 7089 plain washer, normal series.
///
/// The washer lies in the XY plane with its bearing faces at `z = 0` and
/// `z = h`; the bore is centered on the origin. The solid is a single
/// watertight extrusion with a circular outer boundary and a circular hole.
pub fn flat_washer(
  spec : @standards.ISO7089Spec,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> @common.Component {
  let dims = spec.size_dims
  plain_washer(
    "ISO7089-\{dims.size.designation()}",
    spec.metadata(),
    dims.inner_diameter_mm,
    dims.outer_diameter_mm,
    dims.thickness_mm,
    "ISO 7089",
    detail,
    color?,
  )
}

///|
/// iso709x_washer builds an ISO 7091 / 7092 / 7093 / 7090 plain washer.
///
/// The downloaded references for every one of these series are single analytic
/// annuli (two cylinders and two planes), so the sharp-edged plain washer is
/// the standard-correct representation at every detail level.
pub fn iso709x_washer(
  series : @standards.IsoWasherSeries,
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.iso709x_size(series, size) {
    Err(e) => Err(e)
    Ok(dims) =>
      Ok(
        plain_washer(
          "\{@standards.iso709x_prefix(series)}-\{size.designation()}",
          @standards.iso709x_metadata(dims),
          dims.inner_diameter_mm,
          dims.outer_diameter_mm,
          dims.thickness_mm,
          @standards.iso709x_standard(series),
          detail,
          color?,
        ),
      )
  }
}

///|
/// iso7090_washer builds an ISO 7090 plain washer (chamfered normal series,
/// sharp-annulus reference).
pub fn iso7090_washer(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Simplified,
) -> Result[@common.Component, @common.SpecError] {
  iso709x_washer(@standards.IsoWasherSeries::Iso7090, size, detail~)
}

///|
/// iso7091_washer builds an ISO 7091 class C plain washer.
pub fn iso7091_washer(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Simplified,
) -> Result[@common.Component, @common.SpecError] {
  iso709x_washer(@standards.IsoWasherSeries::Iso7091ClassC, size, detail~)
}

///|
/// iso7092_washer builds an ISO 7092 small-series plain washer.
pub fn iso7092_washer(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Simplified,
) -> Result[@common.Component, @common.SpecError] {
  iso709x_washer(@standards.IsoWasherSeries::Iso7092, size, detail~)
}

///|
/// iso7093_washer builds an ISO 7093 large-series plain washer.
pub fn iso7093_washer(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Simplified,
) -> Result[@common.Component, @common.SpecError] {
  iso709x_washer(@standards.IsoWasherSeries::Iso7093, size, detail~)
}

///|
/// din125_washer builds a DIN 125 A plain washer, normal series.
///
/// DIN 125 A is dimensionally identical to ISO 7089 for the modeled sizes and
/// is likewise a single analytic annular solid with no edge chamfer. The M8
/// reference thickness is the ISO 7089 h_max of 1.8 mm (nominal 1.6, limits
/// 1.4..1.8), matching the downloaded DIN 125 A M8 reference within the
/// standard.
pub fn din125_washer(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.din125_spec(size) {
    Err(e) => Err(e)
    Ok(spec) => {
      let dims = spec.size_dims
      Ok(
        plain_washer(
          "DIN125-\{dims.size.designation()}",
          spec.metadata(),
          dims.inner_diameter_mm,
          dims.outer_diameter_mm,
          dims.thickness_mm,
          "DIN 125 A",
          detail,
          color?,
        ),
      )
    }
  }
}

///|
/// din440_washer builds a DIN 440 V large washer with a square hole.
///
/// The washer lies in the XY plane with its faces at `z = 0` and `z = s`; the
/// square hole is centered on the origin with sides parallel to X and Y. The
/// outer surface is one analytic cylinder, the hole walls are four planes, and
/// the end faces are planes with a square hole.
pub fn din440_washer(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Simplified,
  color~ : @cad.Rgb = @cad.Rgb::green(),
) -> Result[@common.Component, @common.SpecError] {
  match @standards.din440_spec(size) {
    Err(e) => Err(e)
    Ok(spec) => {
      let dims = spec.size_dims
      let body = @cad.SquareHoleWasher::new(
        outer_diameter_mm=dims.outer_diameter_mm,
        square_side_mm=dims.square_side_mm,
        thickness_mm=dims.thickness_mm,
      ).as_shape()
      Ok(
        @common.Component::new(
          name="DIN440V-\{dims.size.designation()}",
          metadata=spec.metadata(),
          description="DIN 440 V large washer, square hole: one analytic outer cylinder, four planar square-hole walls, and two planar end faces." +
            edge_chamfer_note(detail, "DIN 440 V"),
          features=@common.FeatureRecord::new(
            modeled=["body", "outer-cylinder", "square-bore", "end-faces"],
            omitted=[
              @common.Omission::new(
                feature="edge-chamfer",
                reason="DIN 440 V does not specify an edge chamfer or deburr; the sharp edge is standard-correct",
              ),
            ],
          ),
        ).add_layer(body, name="body", color~),
      )
    }
  }
}

///|
/// din7349_washer builds a DIN 7349 thick flat washer, heavy pattern.
///
/// The washer is an analytic annular solid of revolution: two cylindrical
/// surfaces and two planar faces. DIN 7349 specifies no edge chamfer, so the
/// sharp edge is standard-correct.
pub fn din7349_washer(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.din7349_spec(size) {
    Err(e) => Err(e)
    Ok(spec) => {
      let dims = spec.size_dims
      Ok(
        plain_washer(
          "DIN7349-\{dims.size.designation()}",
          spec.metadata(),
          dims.inner_diameter_mm,
          dims.outer_diameter_mm,
          dims.thickness_mm,
          "DIN 7349",
          detail,
          color?,
        ),
      )
    }
  }
}

///|
fn edge_chamfer_note(
  detail : @common.DetailLevel,
  standard_label : String,
) -> String {
  match detail {
    Simplified => " No edge treatment is specified by the standard."
    Detailed =>
      " No edge chamfer/deburr is specified by " +
      standard_label +
      "; the sharp edge is standard-correct."
    FullyModeled =>
      " No edge chamfer/deburr is specified by " +
      standard_label +
      "; the sharp edge is standard-correct."
  }
}

///|
/// iso7089_washer validates a request and builds the component.
pub fn iso7089_washer(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Simplified,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.iso7089_spec(size) {
    Err(e) => Err(e)
    Ok(spec) => Ok(flat_washer(spec, detail~))
  }
}
