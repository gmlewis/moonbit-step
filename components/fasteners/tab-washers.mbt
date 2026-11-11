///|
/// din93_tab_washer builds a DIN 93 tab washer with a long external tab.
///
/// The washer lies in the XY plane with its faces at z = 0 and z = s; the bore
/// is centered on the origin and the tab extends in the -X direction. The tab
/// blends into the washer with two concave analytic cylinders. The transition
/// center is at `l / 2 + 2` mm and the tangent fillet radius is derived from
/// it, which matches the downloaded references.
pub fn din93_tab_washer(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Simplified,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match @standards.din93_spec(size) {
    Err(e) => Err(e)
    Ok(spec) => {
      let dims = spec.size_dims
      let r = dims.outer_diameter_mm / 2.0
      let w = dims.tab_width_mm / 2.0
      let xroot = dims.tab_length_mm / 2.0 + 2.0
      if r <= w {
        return Err(
          @common.SpecError::InvalidDimension(
            "DIN 93 tab width must be smaller than the washer diameter",
          ),
        )
      }
      let fillet = (xroot * xroot + w * w - r * r) / (2.0 * (r - w))
      if fillet <= 0.0 {
        return Err(
          @common.SpecError::InvalidDimension(
            "DIN 93 tab transition does not fit the washer",
          ),
        )
      }
      let body = @cad.TabWasher::new(
        outer_diameter_mm=dims.outer_diameter_mm,
        bore_diameter_mm=dims.inner_diameter_mm,
        tab_width_mm=dims.tab_width_mm,
        tab_length_mm=dims.tab_length_mm,
        fillet_radius_mm=fillet,
        thickness_mm=dims.thickness_mm,
      ).as_shape()
      let _ = detail
      Ok(
        @common.Component::new(
          name="DIN93-\{dims.size.designation()}",
          metadata=spec.metadata(),
          description="DIN 93 tab washer: one analytic outer cylinder, two concave analytic transition cylinders, a cylindrical bore, two planar tab sides, a planar tab end, and two planar faces.",
          features=@common.FeatureRecord::new(
            modeled=[
              "body", "outer-cylinder", "transition-fillets", "bore", "tab", "end-faces",
            ],
            approximated=[
              @common.Approximation::new(
                feature="transition-radius",
                kind=@common.ApproximationKind::EngineeringDefault,
                deviation_mm=0.0,
                control="transition center = tab_length/2 + 2 mm",
              ),
            ],
            omitted=[
              @common.Omission::new(
                feature="edge-chamfer",
                reason="DIN 93 specifies no edge chamfer; the sharp edge is standard-correct",
              ),
              @common.Omission::new(
                feature="service-bend",
                reason="the tab is modeled flat; the in-service bend of the tab is not part of the delivered part",
              ),
            ],
          ),
        ).add_layer(body, name="body", color~),
      )
    }
  }
}
