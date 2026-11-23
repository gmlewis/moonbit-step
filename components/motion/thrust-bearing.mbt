///|
/// ThrustBearingSize is one standard metric thrust-bearing envelope.
pub(all) struct ThrustBearingSize {
  designation : String
  bore_mm : Double
  outer_diameter_mm : Double
  height_mm : Double
}

///|
/// thrust_bearing_designations lists the Maker Store `BEAR-F` thrust-bearing
/// sizes.
pub fn thrust_bearing_designations() -> Array[String] {
  ["F5-10M", "F5-12M", "F6-12M", "F8-16M"]
}

///|
/// thrust_bearing_size returns the standard metric thrust-bearing dimensions
/// for a designation.
///
/// Sizes: F5-10M 5x10x4, F5-12M 5x12x4, F6-12M 6x12x4.5, F8-16M 8x16x5
/// (bore x outer diameter x height).
pub fn thrust_bearing_size(
  designation : String,
) -> Result[ThrustBearingSize, @common.SpecError] {
  let token = designation.trim().to_owned().to_upper()
  let (bore, outer, height) = match token {
    "F5-10M" => (5.0, 10.0, 4.0)
    "F5-12M" => (5.0, 12.0, 4.0)
    "F6-12M" => (6.0, 12.0, 4.5)
    "F8-16M" => (8.0, 16.0, 5.0)
    other =>
      return Err(
        @common.InvalidSize(
          "unsupported thrust bearing: \{other}; supported: F5-10M, F5-12M, F6-12M, F8-16M",
        ),
      )
  }
  Ok({
    designation: token,
    bore_mm: bore,
    outer_diameter_mm: outer,
    height_mm: height,
  })
}

///|
/// thrust_bearing builds a standard metric thrust-bearing boundary envelope.
///
/// The envelope is one analytic annular ring (outer diameter, bore, height) with
/// a through bore, an outer seat, and two face frames; the race grooves, ball
/// cage, and rolling elements are declared omissions. The bore is the running
/// shaft interface and the outer diameter the housing seat, matching the other
/// bearing envelopes in this package. No load or life rating is implied.
pub fn thrust_bearing(
  size : ThrustBearingSize,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    @common.require_positive(
      "thrust bearing outer diameter",
      size.outer_diameter_mm,
    ) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if size.bore_mm <= 0.0 || size.bore_mm >= size.outer_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "thrust bearing bore must be positive and smaller than the outer diameter",
      ),
    )
  }
  match @common.require_positive("thrust bearing height", size.height_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let body = @cad.RevolvedProfile::tube(
    size.outer_diameter_mm,
    size.bore_mm,
    size.height_mm,
  ).as_shape()
  let source = "https://makerstore.cc/product/thrust-bearings/ | SKU BEAR-F | standard metric thrust bearing \{size.designation} (bore x OD x height)"
  let features = @common.FeatureRecord::new(
    modeled=["body", "outer-cylinder", "through-bore", "end-faces"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="race-grooves",
        reason="the envelope is one cylindrical ring; race grooves are not modelled",
      ),
      @common.Omission::new(
        feature="ball-cage-and-rolling-elements",
        reason="rolling elements and the cage are boundary geometry only",
      ),
    ],
  )
  Ok(
    with_bushing_connectors(
      @common.Component::new(
        name="thrust-bearing-\{size.designation}",
        metadata=@common.Metadata::new(
          designation="Thrust bearing \{size.designation} (Maker Store BEAR-F)",
          standard="standard metric thrust bearing (Maker Store BEAR-F)",
          family="thrust bearing",
          size=size.designation,
          length_mm=size.height_mm,
          material="bearing steel (label only)",
          source~,
        ),
        description="Metric thrust-bearing boundary envelope: one analytic annular ring with a bore, an outer seat, and two faces. Race grooves, the ball cage, and rolling elements are omitted.",
        features~,
      ).add_layer(body, name="body", color~),
      size.bore_mm,
      size.outer_diameter_mm,
      size.height_mm,
    ),
  )
}

///|
/// thrust_bearing_designation_for maps a bore/outer pair to the matching
/// BEAR-F designation, or reports that no such standard size exists.
fn thrust_bearing_designation_for(
  bore_mm : Double,
  outer_mm : Double,
) -> Result[String, @common.SpecError] {
  for designation in thrust_bearing_designations() {
    match thrust_bearing_size(designation) {
      Ok(size) =>
        if (size.bore_mm - bore_mm).abs() < 1.0e-6 &&
          (size.outer_diameter_mm - outer_mm).abs() < 1.0e-6 {
          return Ok(designation)
        }
      Err(_) => ()
    }
  }
  Err(
    @common.InvalidSize(
      "no BEAR-F thrust bearing with bore \{bore_mm} mm and outer \{outer_mm} mm; supported: F5-10M, F5-12M, F6-12M, F8-16M",
    ),
  )
}

///|
/// thrust_bearing_family exposes the Maker Store `BEAR-F` thrust bearings as a
/// validated design family keyed by bore and outer diameter, with one preset per
/// standard size.
pub fn thrust_bearing_family() -> Result[
  @common.DesignFamily,
  @common.SpecError,
] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="bore",
      default_mm=5.0,
      min_mm=4.0,
      max_mm=8.0,
      description="bore (shaft clearance) diameter",
    ),
    @common.ParamSpec::new(
      name="outer",
      default_mm=10.0,
      min_mm=10.0,
      max_mm=16.0,
      description="outer (housing seat) diameter",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="makerstore-thrust-bearing",
      specs~,
      description="Maker Store BEAR-F thrust-bearing boundary envelopes.",
      build=fn(parameters) {
        let bore = match parameters.get("bore") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let outer = match parameters.get("outer") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let designation = match thrust_bearing_designation_for(bore, outer) {
          Ok(d) => d
          Err(e) => return Err(e)
        }
        let size = match thrust_bearing_size(designation) {
          Ok(s) => s
          Err(e) => return Err(e)
        }
        thrust_bearing(size)
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let mut out = family
  for designation in ["F5-10M", "F5-12M", "F6-12M", "F8-16M"] {
    let size = match thrust_bearing_size(designation) {
      Ok(s) => s
      Err(e) => return Err(e)
    }
    out = match
      out.with_variant(designation.to_lower(), [
        ("bore", size.bore_mm),
        ("outer", size.outer_diameter_mm),
      ]) {
      Ok(f) => f
      Err(e) => return Err(e)
    }
  }
  Ok(out)
}
