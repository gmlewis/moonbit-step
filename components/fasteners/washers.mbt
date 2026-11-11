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
  let policy = @common.DetailPolicy::for_level(detail)
  let dims = spec.size_dims
  let segments = clamp_segments(policy.circle_segments)
  let name = "ISO7089-\{dims.size.designation()}"
  let metal = match color {
    Some(c) => c
    None => @cad.Rgb::green()
  }
  let outer = circle_profile(dims.outer_diameter_mm, segments~)
  let hole = hole_profile(dims.inner_diameter_mm, segments~)
  let body = @cad.ExtrudedProfile::new(outer, dims.thickness_mm, holes=[hole])
  let features = @common.FeatureRecord::new(
    modeled=["body"],
    approximated=[
      polyline_circle_approximation(
        "outer-boundary",
        dims.outer_diameter_mm / 2.0,
        segments,
      ),
      polyline_circle_approximation(
        "through-bore",
        dims.inner_diameter_mm / 2.0,
        segments,
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="edge-chamfer",
        reason="ISO 7089 does not specify an edge chamfer or deburr; the sharp edge is the standard-correct representation",
      ),
    ],
  )
  @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Plain washer, normal series; a single extrusion with a circular bore. ISO 7089 specifies no edge chamfer, so the sharp edge is modeled at every detail level and no chamfer is claimed." +
      edge_chamfer_note(detail),
    features~,
  ).add_layer(body, name="body", color=metal)
}

///|
fn edge_chamfer_note(detail : @common.DetailLevel) -> String {
  match detail {
    Simplified => " No edge treatment is specified by the standard."
    Detailed =>
      " No edge chamfer/deburr is specified by ISO 7089; the sharp edge is standard-correct."
    FullyModeled =>
      " No edge chamfer/deburr is specified by ISO 7089; the sharp edge is standard-correct."
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
