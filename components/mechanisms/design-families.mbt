///|
/// linkage_family returns the reusable design family for the linkage-bar
/// builder.
///
/// The family exposes validated millimetre parameters, an optional adjustment
/// slot, and the `compact`/`long` presets. It is the same design the
/// `components/examples/mechanism_design` example builds; keeping it in the
/// library lets other programs and tools reuse the schema.
pub fn linkage_family() -> Result[@common.DesignFamily, @common.SpecError] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="length",
      default_mm=120.0,
      min_mm=60.0,
      max_mm=400.0,
      description="linkage bar length",
    ),
    @common.ParamSpec::new(
      name="width",
      default_mm=24.0,
      min_mm=12.0,
      max_mm=80.0,
      description="linkage bar width",
    ),
    @common.ParamSpec::new(
      name="thickness",
      default_mm=6.0,
      min_mm=3.0,
      max_mm=20.0,
      description="linkage bar thickness",
    ),
    @common.ParamSpec::new(
      name="pivot",
      default_mm=8.0,
      min_mm=4.0,
      max_mm=20.0,
      description="pivot hole diameter",
    ),
    @common.ParamSpec::new(
      name="slotLength",
      default_mm=0.0,
      min_mm=0.0,
      max_mm=200.0,
      description="adjustment slot length (0 = none)",
    ),
    @common.ParamSpec::new(
      name="slotWidth",
      default_mm=0.0,
      min_mm=0.0,
      max_mm=40.0,
      description="adjustment slot width (0 = none)",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="pivot-linkage",
      specs~,
      description="A stadium linkage bar with two pivot holes and an optional adjustment slot.",
      build=fn(parameters) {
        let length = match parameters.get("length") {
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
        let pivot = match parameters.get("pivot") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let slot_length = match parameters.get("slotLength") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let slot_width = match parameters.get("slotWidth") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        linkage_bar(
          length,
          width,
          thickness,
          pivot,
          slot_length_mm=slot_length,
          slot_width_mm=slot_width,
        )
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let family = match
    family.with_variant("compact", [("length", 80.0), ("width", 16.0)]) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  family.with_variant("long", [("length", 240.0), ("width", 32.0)])
}
