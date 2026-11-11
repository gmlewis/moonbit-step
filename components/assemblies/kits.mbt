///|
/// metric_hardware_kit builds a display assembly with one socket head cap
/// screw, one flat washer under its head, and one hex nut near the free end.
///
/// All three pieces are separate components with their own parametric
/// identity. The screw axis is +Z, so the kit stands on the Z = 0 plane.
pub fn metric_hardware_kit(
  size : @standards.MetricSize,
  screw_length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
) -> Result[Assembly, @common.SpecError] {
  let screw = match @fasteners.iso4762_screw(size, screw_length_mm, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let nut = match @fasteners.iso4032_nut(size, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let washer = match @fasteners.iso7089_washer(size, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let washer_height = washer.size().2
  // Put the nut at the free end of the shank. A fixed offset (the old code
  // used 2 mm) made short valid screws overlap the washer and head.
  let nut_z = 0.0
  let name = "hardware-kit-\{size.designation()}-\{@fasteners.format_length(screw_length_mm)}"
  let assembly = Assembly::new(
      name~,
      description="Socket head cap screw with flat washer and hex nut, separated along the screw axis.",
    )
    .add(
      screw,
      // Datum is the head underside; lift it so the tip rests on z = 0.
      placement=@common.Placement::translation(0.0, 0.0, screw_length_mm),
      instance_name="screw",
    )
    .add(
      washer,
      placement=@common.Placement::translation(
        0.0,
        0.0,
        screw_length_mm - washer_height,
      ),
      instance_name="washer",
    )
    .add(
      nut,
      placement=@common.Placement::translation(0.0, 0.0, nut_z),
      instance_name="nut",
    )
  Ok(assembly)
}

///|
/// fastener_grid_plate builds a plate-like assembly: a set of screws through a
/// rectangular pattern, each with a washer and a nut. The plate itself is not
/// modeled; this is a fastener-pattern demonstration.
///
/// The screws sit with their heads above `z = 0` and shanks along -Z, so the
/// pattern reads like a bolted joint viewed from the head side.
pub fn fastener_grid_plate(
  size : @standards.MetricSize,
  screw_length_mm : Double,
  cols : Int32,
  rows : Int32,
  pitch_x_mm : Double,
  pitch_y_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
) -> Result[Assembly, @common.SpecError] {
  let screw = match @fasteners.iso4762_screw(size, screw_length_mm, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let nut = match @fasteners.iso4032_nut(size, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let washer = match @fasteners.iso7089_washer(size, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let washer_height = washer.size().2
  let name = "fastener-grid-\{size.designation()}-\{cols}x\{rows}"
  let mut assembly = Assembly::new(
    name~,
    description="Rectangular fastener pattern with an ISO 4762 screw, ISO 7089 washer, and ISO 4032 nut per position.",
  )
  let x0 = -((cols - 1).to_double() * pitch_x_mm) / 2.0
  let y0 = -((rows - 1).to_double() * pitch_y_mm) / 2.0
  for iy in 0..<rows {
    for ix in 0..<cols {
      let x = x0 + ix.to_double() * pitch_x_mm
      let y = y0 + iy.to_double() * pitch_y_mm
      let index = iy * cols + ix + 1
      // Screw: head upward. The datum is the head underside, which sits on
      // the pattern face at z = 0; the shank spans -L .. 0.
      let screw_placement = @common.Placement::translation(x, y, 0.0)
      assembly = assembly.add(
        screw,
        placement=screw_placement,
        instance_name="screw-\{index}",
      )
      // Washer under the head (head bottom is at z = 0).
      let washer_placement = @common.Placement::translation(
        x,
        y,
        -washer_height,
      )
      assembly = assembly.add(
        washer,
        placement=washer_placement,
        instance_name="washer-\{index}",
      )
      // Nut at the free end: the shank spans z = -L .. 0.
      let nut_placement = @common.Placement::translation(x, y, -screw_length_mm)
      assembly = assembly.add(
        nut,
        placement=nut_placement,
        instance_name="nut-\{index}",
      )
    }
  }
  Ok(assembly)
}
