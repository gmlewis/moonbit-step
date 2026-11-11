///|
/// plate_with_hole builds a generic rectangular plate with a central through
/// hole, centred on the origin in X and Y with its base at z = 0.
///
/// The plate is a parametric engineering envelope, not a standard part. The
/// hole is a polyline approximation of a circle; its deviation is recorded in
/// the feature record.
pub fn plate_with_hole(
  width_mm : Double,
  depth_mm : Double,
  thickness_mm : Double,
  hole_diameter_mm : Double,
  name~ : String = "plate",
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("plate width", width_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("plate depth", depth_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("plate thickness", thickness_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if hole_diameter_mm <= 0.0 ||
    hole_diameter_mm >= width_mm ||
    hole_diameter_mm >= depth_mm {
    return Err(
      @common.InvalidDimension(
        "plate hole diameter must be positive and smaller than the plate",
      ),
    )
  }
  let segments = 48
  let outer = @cad.Profile2D::centered_rect(width_mm, depth_mm)
  let hole = @cad.Profile2D::circle(hole_diameter_mm, segments~).rev()
  let body = @cad.ExtrudedProfile::new(outer, thickness_mm, holes=[hole])
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Plate \{width_mm} x \{depth_mm} x \{thickness_mm}",
        family="plate with hole",
        size="\{width_mm}x\{depth_mm}x\{thickness_mm}",
        source="Parametric plate envelope with a central through hole; no standard table is implied.",
      ),
      description="Rectangular plate with a central through hole.",
      features=@common.FeatureRecord::new(
        modeled=["body"],
        approximated=[
          @common.Approximation::new(
            feature="through-hole",
            kind=@common.ApproximationKind::PolylineArc,
            deviation_mm=@common.chord_deviation(
              hole_diameter_mm / 2.0,
              segments,
            ),
            control="circle_segments=\{segments}",
          ),
        ],
        omitted=[
          @common.Omission::new(
            feature="edge-chamfer",
            reason="not modelled by this builder",
          ),
        ],
      ),
    ).add_layer(body, name="body", color=@cad.Rgb::grey()),
  )
}

///|
/// bolted_joint builds a through-bolted joint: two plates clamped by an ISO
/// 4762 screw, an ISO 7089 washer under the head, and an ISO 4032 nut below
/// the bottom plate.
///
/// The screw axis is +Z, the bottom plate is at z = 0..t, the top plate at
/// z = t..2t, the washer sits on the top plate, and the nut sits below the
/// bottom plate. The plate holes are 0.4 mm larger than the screw so the
/// shank clears them; the nut bore matches the nominal shank and is a contact,
/// not a collision.
///
/// The default screw length is exactly the nut + plates + washer stack. Pass
/// `screw_length_mm` to select a standard length; a longer screw protrudes
/// past the nut and leaves a corresponding gap under the head unless the stack
/// is shimmed. A length shorter than the stack is rejected.
pub fn bolted_joint(
  size : @standards.MetricSize,
  plate_width_mm : Double,
  plate_depth_mm : Double,
  plate_thickness_mm : Double,
  screw_length_mm? : Double,
  detail~ : @common.DetailLevel = Detailed,
) -> Result[Assembly, @common.SpecError] {
  let nut = match @fasteners.iso4032_nut(size, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let washer = match @fasteners.iso7089_washer(size, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let nut_height = nut.size().2
  let washer_height = washer.size().2
  let diameter = size.nominal_diameter_mm()
  // Overall screw length from shank end to under-head face: nut + plates +
  // washer, so the nut engages the shank and the head clamps the washer.
  let required_length = nut_height + 2.0 * plate_thickness_mm + washer_height
  let screw_length = match screw_length_mm {
    Some(l) => l
    None => required_length
  }
  if screw_length < required_length {
    return Err(
      @common.InvalidDimension(
        "screw length \{screw_length} mm is shorter than the nut + plates + washer stack \{required_length} mm",
      ),
    )
  }
  let screw = match @fasteners.iso4762_screw(size, screw_length, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let hole_diameter = diameter + 0.4
  let plate = match
    plate_with_hole(
      plate_width_mm,
      plate_depth_mm,
      plate_thickness_mm,
      hole_diameter,
      name="plate",
    ) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let screw_z = -nut_height
  let top_plate_z = plate_thickness_mm
  let washer_z = 2.0 * plate_thickness_mm
  let name = "bolted-joint-\{size.designation()}-\{@fasteners.format_length(plate_thickness_mm)}"
  let assembly = Assembly::new(
      name~,
      description="Through-bolted joint: two plates, an ISO 4762 screw, an ISO 7089 washer, and an ISO 4032 nut.",
    )
    .add(plate, instance_name="plate-bottom")
    .add(
      plate,
      placement=@common.Placement::translation(0.0, 0.0, top_plate_z),
      instance_name="plate-top",
    )
    .add(
      washer,
      placement=@common.Placement::translation(0.0, 0.0, washer_z),
      instance_name="washer",
    )
    .add(
      screw,
      placement=@common.Placement::translation(0.0, 0.0, screw_z),
      instance_name="screw",
    )
    .add(
      nut,
      placement=@common.Placement::translation(0.0, 0.0, -nut_height),
      instance_name="nut",
    )
  Ok(assembly)
}
