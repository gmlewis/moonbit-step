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
