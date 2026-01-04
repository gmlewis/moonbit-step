///|
/// Electrical reporting (non-geometry utilities).
///
/// This file intentionally keeps analysis/report code separate from the
/// geometry construction in main.mbt and bfem-cage.mbt.

///|
async fn report_electrical_geometry(params : Params) -> Unit {
  // NOTE: Print only to stderr so stdout remains a clean STEP stream.
  let wire_width_mm = params.wire_width
  let area_mm2 = wire_width_mm * wire_width_mm
  let area_m2 = area_mm2 * 1.0e-6
  let total_helix_length_mm = if params.nocoil {
    0.0
  } else {
    total_bifilar_helix_centerline_length_mm(params)
  }
  let total_helix_length_m = total_helix_length_mm * 1.0e-3
  let rdc_est = if total_helix_length_m == 0.0 {
    0.0
  } else {
    params.rho * total_helix_length_m / area_m2
  }
  @cli.eprintln("bfem:report:wire_width_mm=\{wire_width_mm}")
  @cli.eprintln("bfem:report:area_mm2=\{area_mm2}")
  @cli.eprintln("bfem:report:area_m2=\{area_m2}")
  @cli.eprintln("bfem:report:helix_length_mm=\{total_helix_length_mm}")
  @cli.eprintln("bfem:report:helix_length_m=\{total_helix_length_m}")
  @cli.eprintln("bfem:report:rho_ohm_m=\{params.rho}")
  @cli.eprintln("bfem:report:rdc_est_ohm=\{rdc_est}")
  @cli.eprintln(
    "bfem:report:note=helix-only length; connectors/cage not included",
  )
  if !params.nocage {
    let (radius, height) = coil_turn_dimensions(params.num_pairs, params)
    let m = estimate_bfem_cage_conductors(
      size=(radius, radius, height),
      params~,
    )
    let cage_rdc = params.rho * 1.0e3 * m.cage.mm_over_mm2
    let exit_rdc = params.rho * 1.0e3 * m.exit_wires.mm_over_mm2
    @cli.eprintln("bfem:report:cage_length_mm=\{m.cage.length_mm}")
    @cli.eprintln("bfem:report:cage_volume_mm3=\{m.cage.volume_mm3}")
    @cli.eprintln("bfem:report:cage_segments=\{m.cage.segments}")
    @cli.eprintln("bfem:report:cage_rdc_est_ohm=\{cage_rdc}")
    @cli.eprintln("bfem:report:exit_length_mm=\{m.exit_wires.length_mm}")
    @cli.eprintln("bfem:report:exit_volume_mm3=\{m.exit_wires.volume_mm3}")
    @cli.eprintln("bfem:report:exit_segments=\{m.exit_wires.segments}")
    @cli.eprintln("bfem:report:exit_rdc_est_ohm=\{exit_rdc}")
    @cli.eprintln(
      "bfem:report:note2=cage/exit Rdc assumes current flows along each extrusion axis; treat as rough",
    )
  }
}

///|
fn total_bifilar_helix_centerline_length_mm(params : Params) -> Double {
  // The model creates two helices per pair (start_angle and start_angle+180).
  // For length purposes, start angle doesn’t matter, so total length is twice
  // the sum of per-pair helix centerline lengths.
  let mut sum = 0.0
  for pair_num in 1..=params.num_pairs {
    sum = sum + coil_helix_centerline_length_mm(pair_num, params)
  }
  2.0 * sum
}

///|
fn coil_helix_centerline_length_mm(pair_num : Int, params : Params) -> Double {
  let (radius, height_per_turn) = coil_turn_dimensions(pair_num, params)
  let start_angle = 180.0 *
    (pair_num.to_double() - 1) /
    params.num_pairs.to_double()
  let path = @cad.helix_path(
    pos=params.pos,
    size_per_turn=(radius, radius, height_per_turn),
    num_turns=params.vert_turns,
    num_segs_per_turn=params.num_segs,
    start_angle~,
  )
  path_length_mm(path.points)
}

///|
fn path_length_mm(points : Array[Vec3]) -> Double {
  if points.length() < 2 {
    return 0.0
  }
  let mut sum = 0.0
  for i in 1..<points.length() {
    sum = sum + vec3_distance(points[i - 1], points[i])
  }
  sum
}

///|
fn vec3_distance(a : Vec3, b : Vec3) -> Double {
  let dx = b.0 - a.0
  let dy = b.1 - a.1
  let dz = b.2 - a.2
  (dx * dx + dy * dy + dz * dz).sqrt()
}
