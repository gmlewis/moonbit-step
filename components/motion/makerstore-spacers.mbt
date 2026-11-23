///|
/// makerstore_aluminum_spacer builds a Maker Store metric aluminum spacer.
///
/// The default OD 10 mm / ID 5 mm / length 10 mm matches SKU `SHIM-SPAC`
/// (live product page: OD 10 mm, M5 / 5 mm bore; lengths 3, 6, 6.5, 9, 10, 20,
/// 30, 35, and 40 mm). Geometry is delegated to `spacer`, so both surfaces stay
/// exact analytic cylinders; only the provenance is Maker Store specific.
pub fn makerstore_aluminum_spacer(
  length_mm~ : Double = 10.0,
  outer_diameter_mm~ : Double = 10.0,
  inner_diameter_mm~ : Double = 5.0,
  color~ : @cad.Rgb = @cad.Rgb::green(),
) -> Result[@common.Component, @common.SpecError] {
  let part = match
    spacer(outer_diameter_mm, inner_diameter_mm, length_mm, color~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let source = "https://makerstore.cc/product/metric-aluminum-spacers/ | SKU SHIM-SPAC | aluminium | OD \{outer_diameter_mm} mm, bore \{inner_diameter_mm} mm, length \{length_mm} mm | live product page lists lengths 3, 6, 6.5, 9, 10, 20, 30, 35, 40 mm"
  Ok(
    part
    .with_name("makerstore-spacer-\{length_mm}")
    .with_metadata(
      @common.Metadata::new(
        designation="Maker Store aluminum spacer OD \{@cad.fmt_double(outer_diameter_mm, None)} / ID \{@cad.fmt_double(inner_diameter_mm, None)} x \{@cad.fmt_double(length_mm, None)} (SHIM-SPAC)",
        standard="Maker Store metric aluminum spacer (SHIM-SPAC)",
        family="Maker Store aluminum spacer",
        size="OD\{@cad.fmt_double(outer_diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}",
        length_mm~,
        material="aluminium",
        source~,
      ),
    ),
  )
}

///|
/// makerstore_spacer_family exposes the metric aluminum spacer as a validated
/// design family with one preset per real `SHIM-SPAC` length.
pub fn makerstore_spacer_family() -> Result[
  @common.DesignFamily,
  @common.SpecError,
] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="outer",
      default_mm=10.0,
      min_mm=4.0,
      max_mm=30.0,
      description="outer diameter",
    ),
    @common.ParamSpec::new(
      name="inner",
      default_mm=5.0,
      min_mm=1.0,
      max_mm=25.0,
      description="bore diameter",
    ),
    @common.ParamSpec::new(
      name="length",
      default_mm=10.0,
      min_mm=1.0,
      max_mm=100.0,
      description="spacer length",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="makerstore-aluminum-spacer",
      specs~,
      description="Maker Store metric aluminum spacer (OD 10, ID 5) with the published length presets.",
      build=fn(parameters) {
        let outer = match parameters.get("outer") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let inner = match parameters.get("inner") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let length = match parameters.get("length") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        makerstore_aluminum_spacer(
          length_mm=length,
          outer_diameter_mm=outer,
          inner_diameter_mm=inner,
        )
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let mut out = family
  for length in [3.0, 6.0, 6.5, 9.0, 10.0, 20.0, 30.0, 35.0, 40.0] {
    let name = "len-\{@cad.fmt_double(length, None)}"
    out = match out.with_variant(name, [("length", length)]) {
      Ok(f) => f
      Err(e) => return Err(e)
    }
  }
  Ok(out)
}
