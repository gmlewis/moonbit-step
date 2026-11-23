///|
/// makerstore_corner_bracket builds a Maker Store V-Slot corner bracket and
/// attaches Maker Store provenance.
///
/// The geometry is the existing `vslot_corner_bracket` gusseted 20-series form,
/// so this is a provenance-bearing preset, not a second bracket builder. The
/// defaults reproduce the `BRAC-90CAST` envelope (20 x 20 x 17 mm cast bracket;
/// the cast draft, edge rounds, and locating tabs are declared omissions). A
/// 40 mm leg selects the 40-series `BRAC-40S-90CAST-B` envelope.
pub fn makerstore_corner_bracket(
  leg_mm~ : Double = 20.0,
  width_mm~ : Double = 20.0,
  thickness_mm~ : Double = 3.0,
  gusset_thickness_mm~ : Double = 3.0,
  slot_width_mm~ : Double = 5.5,
  slot_length_mm~ : Double = 10.0,
  slot_shift_mm~ : Double = 1.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let part = match
    vslot_corner_bracket(
      leg_mm~,
      width_mm~,
      thickness_mm~,
      gusset_thickness_mm~,
      slot_width_mm~,
      slot_length_mm~,
      slot_shift_mm~,
      color~,
    ) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let (sku, price, slug) = if leg_mm < 30.0 {
    ("BRAC-90CAST", "$1.80", "cast-90-degree-corner-bracket")
  } else {
    ("BRAC-40S-90CAST-B", "price varies", "brac-40s-90cast-b")
  }
  let source = "https://makerstore.cc/product/\{slug}/ | SKU \{sku} | \{price} | \{@cad.fmt_double(leg_mm, None)} mm gusseted V-Slot corner bracket envelope; cast draft, edge rounds, and locating tabs omitted"
  Ok(
    part
    .with_name("makerstore-corner-bracket-\{@cad.fmt_double(leg_mm, None)}")
    .with_metadata(
      @common.Metadata::new(
        designation="Maker Store V-Slot corner bracket \{@cad.fmt_double(leg_mm, None)} mm (\{sku})",
        standard="Maker Store V-Slot corner bracket (\{sku})",
        family="Maker Store V-Slot corner bracket",
        size="\{@cad.fmt_double(leg_mm, None)}",
        material="aluminium (cast; material not further specified)",
        source~,
      ),
    ),
  )
}

///|
/// makerstore_corner_bracket_family exposes the Maker Store corner bracket as a
/// validated design family with 20-series and 40-series presets.
pub fn makerstore_corner_bracket_family() -> Result[
  @common.DesignFamily,
  @common.SpecError,
] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="leg",
      default_mm=20.0,
      min_mm=15.0,
      max_mm=80.0,
      description="bracket leg length",
    ),
    @common.ParamSpec::new(
      name="width",
      default_mm=20.0,
      min_mm=15.0,
      max_mm=80.0,
      description="bracket width",
    ),
    @common.ParamSpec::new(
      name="thickness",
      default_mm=3.0,
      min_mm=1.5,
      max_mm=10.0,
      description="leg thickness",
    ),
    @common.ParamSpec::new(
      name="gusset",
      default_mm=3.0,
      min_mm=1.0,
      max_mm=20.0,
      description="side gusset thickness",
    ),
    @common.ParamSpec::new(
      name="slotWidth",
      default_mm=5.5,
      min_mm=3.0,
      max_mm=10.0,
      description="M5-clearance slot width",
    ),
    @common.ParamSpec::new(
      name="slotLength",
      default_mm=10.0,
      min_mm=5.0,
      max_mm=40.0,
      description="slot length",
    ),
    @common.ParamSpec::new(
      name="slotShift",
      default_mm=1.0,
      min_mm=0.0,
      max_mm=10.0,
      description="slot centre shift toward the free end",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="makerstore-corner-bracket",
      specs~,
      description="Maker Store gusseted V-Slot corner bracket with the 20-series and 40-series presets.",
      build=fn(parameters) {
        let leg = match parameters.get("leg") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let width = match parameters.get("width") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let thickness = match parameters.get("thickness") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let gusset = match parameters.get("gusset") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let slot_width = match parameters.get("slotWidth") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let slot_length = match parameters.get("slotLength") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let slot_shift = match parameters.get("slotShift") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        makerstore_corner_bracket(
          leg_mm=leg,
          width_mm=width,
          thickness_mm=thickness,
          gusset_thickness_mm=gusset,
          slot_width_mm=slot_width,
          slot_length_mm=slot_length,
          slot_shift_mm=slot_shift,
        )
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let family = match
    family.with_variant("brac-90cast", [
      ("leg", 20.0),
      ("width", 20.0),
      ("thickness", 3.0),
      ("gusset", 3.0),
      ("slotWidth", 5.5),
      ("slotLength", 10.0),
      ("slotShift", 1.0),
    ]) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  family.with_variant("brac-40s-90cast-b", [
    ("leg", 40.0),
    ("width", 40.0),
    ("thickness", 4.0),
    ("gusset", 4.0),
    ("slotWidth", 5.5),
    ("slotLength", 10.0),
    ("slotShift", 1.0),
  ])
}
