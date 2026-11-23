///|
/// makerstore_grid_count returns how many holes a centred, pitch-spaced grid
/// fits along `length_mm` when the end margin is one pitch.
///
/// For the flagship 40 mm leg at a 10 mm pitch this is 3 holes (10, 20, 30 mm),
/// which matches the Maker Store `PLATE-40X40L` drawing; an 80 mm leg gives 7.
fn makerstore_grid_count(length_mm : Double, pitch_mm : Double) -> Int32 {
  let raw = (length_mm / pitch_mm).floor().to_int() - 1
  if raw < 1 {
    1
  } else {
    raw
  }
}

///|
/// makerstore_l_plate builds a Maker Store 20-series L plate / bracket with a
/// centred square hole grid on both legs.
///
/// The defaults reproduce `PLATE-40X40L`: 40 x 40 mm legs, 3 mm thick, a 3 x 3
/// grid of 5 mm clearance holes on 10 mm centres with 10 mm margins. The hole
/// count follows `makerstore_grid_count`, so changing the leg length or pitch
/// keeps the grid centred. Geometry is delegated to `l_bracket`, so this is a
/// provenance-bearing preset of one L-bracket builder, not a second geometry.
///
/// Frame: the base leg lies on `z = 0 .. thickness` along +X; the upright leg
/// rises along +Z; both are `width` wide, centred on `y = 0`. Base holes pass
/// through Z and upright holes through X.
pub fn makerstore_l_plate(
  leg_a_mm~ : Double = 40.0,
  leg_b_mm~ : Double = 40.0,
  width_mm~ : Double = 40.0,
  thickness_mm~ : Double = 3.0,
  hole_diameter_mm~ : Double = 5.0,
  pitch_mm~ : Double = 10.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  if pitch_mm <= 0.0 {
    return Err(@common.InvalidDimension("L plate hole pitch must be positive"))
  }
  let rows_a = makerstore_grid_count(leg_a_mm, pitch_mm)
  let rows_b = makerstore_grid_count(leg_b_mm, pitch_mm)
  let cols = makerstore_grid_count(width_mm, pitch_mm)
  let part = match
    l_bracket(
      leg_a_mm,
      leg_b_mm,
      width_mm,
      thickness_mm,
      hole_diameter_mm,
      holes_per_leg=rows_a,
      holes_per_leg_b=rows_b,
      holes_across=cols,
      pitch_mm~,
      color~,
    ) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let size = "\{@cad.fmt_double(leg_a_mm, None)}x\{@cad.fmt_double(leg_b_mm, None)}"
  let (sku, price, slug) = if nearly_equal_mm(leg_a_mm, 40.0) &&
    nearly_equal_mm(leg_b_mm, 40.0) {
    ("PLATE-40X40L", "$4.73", "40x40-l-plate")
  } else if nearly_equal_mm(leg_a_mm, 80.0) && nearly_equal_mm(leg_b_mm, 40.0) {
    ("PLATE-40X80L", "$6.75", "40x80-l-plate")
  } else {
    ("PLATE-MAKERSTORE-L", "price varies", "joining-plates")
  }
  let source = "https://makerstore.cc/product/\{slug}/ | SKU \{sku} | aluminium, black anodized brushed | \{price} | \{size} mm legs, \{thickness_mm} mm thick, \{hole_diameter_mm} mm holes on \{pitch_mm} mm centres (Maker Store 20-series joining plate)"
  Ok(
    part
    .with_name("makerstore-l-plate-\{size}")
    .with_metadata(
      @common.Metadata::new(
        designation="Maker Store \{size} L Plate / Bracket (\{sku})",
        standard="Maker Store 20-series V-Slot joining plate (\{sku})",
        family="Maker Store L plate / bracket",
        size~,
        material="aluminium, black anodized brushed",
        source~,
      ),
    ),
  )
}

///|
/// nearly_equal_mm compares two millimetre lengths within a fixed tolerance.
fn nearly_equal_mm(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
/// l_plate_family exposes the Maker Store L plate as a validated design family.
///
/// Parameters are the leg lengths, width, thickness, hole diameter, and hole
/// pitch. The registered presets are the two real SKUs, `plate-40x40l`
/// (`PLATE-40X40L`, $4.73) and `plate-40x80l` (`PLATE-40X80L`, $6.75). The
/// 40x80 hole count is derived from the same 10 mm pattern; that page has no
/// dimensioned drawing in the saved material.
pub fn l_plate_family() -> Result[@common.DesignFamily, @common.SpecError] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="legA",
      default_mm=40.0,
      min_mm=20.0,
      max_mm=240.0,
      description="base leg length",
    ),
    @common.ParamSpec::new(
      name="legB",
      default_mm=40.0,
      min_mm=20.0,
      max_mm=240.0,
      description="upright leg length",
    ),
    @common.ParamSpec::new(
      name="width",
      default_mm=40.0,
      min_mm=10.0,
      max_mm=120.0,
      description="leg width",
    ),
    @common.ParamSpec::new(
      name="thickness",
      default_mm=3.0,
      min_mm=1.0,
      max_mm=10.0,
      description="plate thickness",
    ),
    @common.ParamSpec::new(
      name="hole",
      default_mm=5.0,
      min_mm=2.0,
      max_mm=12.0,
      description="hole diameter",
    ),
    @common.ParamSpec::new(
      name="pitch",
      default_mm=10.0,
      min_mm=5.0,
      max_mm=50.0,
      description="hole grid pitch",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="makerstore-l-plate",
      specs~,
      description="Maker Store 20-series L plate with a centred hole grid on both legs.",
      build=fn(parameters) {
        let leg_a = match parameters.get("legA") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let leg_b = match parameters.get("legB") {
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
        let hole = match parameters.get("hole") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let pitch = match parameters.get("pitch") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        makerstore_l_plate(
          leg_a_mm=leg_a,
          leg_b_mm=leg_b,
          width_mm=width,
          thickness_mm=thickness,
          hole_diameter_mm=hole,
          pitch_mm=pitch,
        )
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let family = match
    family.with_variant("plate-40x40l", [
      ("legA", 40.0),
      ("legB", 40.0),
      ("width", 40.0),
      ("thickness", 3.0),
      ("hole", 5.0),
      ("pitch", 10.0),
    ]) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  family.with_variant("plate-40x80l", [
    ("legA", 80.0),
    ("legB", 40.0),
    ("width", 40.0),
    ("thickness", 3.0),
    ("hole", 5.0),
    ("pitch", 10.0),
  ])
}
