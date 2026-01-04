///|
/// PEEC / solver exports (non-geometry utilities).
///
/// This file intentionally keeps analysis/export code separate from the
/// geometry construction in main.mbt and bfem-cage.mbt.

///|
async fn export_helix_centerlines_json(
  params : Params,
  out_path : String,
) -> Unit {
  // This intentionally exports *only* the helix centerlines.
  // For PEEC, it’s usually better to export the conductor “intent” rather than
  // try to convert STEP/STL into a solver-specific discretization.
  //
  // Units: millimeters.
  let builder = StringBuilder::new()
  builder.write_string("{\"schema\":\"bfem:centerlines:v1\"")
  builder.write_string(",\"units\":\"mm\"")
  builder.write_string(",\"params\":{")
  builder.write_string("\"innerDiam_mm\":\{params.inner_diam}")
  builder.write_string(",\"numPairs\":\{params.num_pairs}")
  builder.write_string(",\"numSegs\":\{params.num_segs}")
  builder.write_string(",\"vertTurns\":\{params.vert_turns}")
  builder.write_string(",\"wireWidth_mm\":\{params.wire_width}")
  builder.write_string(",\"wireGap_mm\":\{params.wire_gap}")
  builder.write_string(
    ",\"pos\":[\{params.pos.0},\{params.pos.1},\{params.pos.2}]",
  )
  builder.write_string("}")
  builder.write_string(
    ",\"cross_section\":{\"shape\":\"square\",\"width_mm\":\{params.wire_width}}",
  )
  let delta_z = (params.wire_gap + params.wire_width) /
    (params.num_pairs.to_double() - 1)
  builder.write_string(",\"paths\":[")
  let mut first_path = true
  for pair_num in 1..=params.num_pairs {
    let z_off = (pair_num - 1).to_double() * delta_z
    let local_pos = (params.pos.0, params.pos.1, params.pos.2 + z_off)
    let local_params = { ..params, pos: local_pos }
    let start_angle = 180.0 *
      (pair_num.to_double() - 1) /
      params.num_pairs.to_double()
    let (radius, height_per_turn) = coil_turn_dimensions(pair_num, local_params)

    // Two helices per pair: start_angle and start_angle + 180.
    let path_red = @cad.helix_path(
      pos=local_params.pos,
      size_per_turn=(radius, radius, height_per_turn),
      num_turns=local_params.vert_turns,
      num_segs_per_turn=local_params.num_segs,
      start_angle~,
    )
    let path_green = @cad.helix_path(
      pos=local_params.pos,
      size_per_turn=(radius, radius, height_per_turn),
      num_turns=local_params.vert_turns,
      num_segs_per_turn=local_params.num_segs,
      start_angle=start_angle + 180,
    )
    first_path = emit_centerline_path_json(
      builder,
      first_path,
      "bfem:coil:red:pair-\{pair_num}",
      pair_num,
      start_angle,
      path_red.points,
    )
    first_path = emit_centerline_path_json(
      builder,
      first_path,
      "bfem:coil:green:pair-\{pair_num}",
      pair_num,
      start_angle + 180,
      path_green.points,
    )
  }
  builder.write_string("]}")
  @fs.write_file(
    out_path,
    @encoding/utf8.encode(builder.to_string()),
    create=0o644,
    truncate=true,
  ) catch {
    err => {
      @cli.eprintln("error: failed to write centerlines JSON: \{err}")
      abort("")
    }
  }
}

///|
fn emit_centerline_path_json(
  builder : StringBuilder,
  first_path : Bool,
  name : String,
  pair_num : Int,
  start_angle_deg : Double,
  points : Array[Vec3],
) -> Bool {
  if !first_path {
    builder.write_char(',')
  }
  builder.write_string("{\"name\":\"")
  // Names are controlled strings (no quotes expected), so minimal escaping.
  builder.write_string(name)
  builder.write_string("\"")
  builder.write_string(",\"pair\":\{pair_num}")
  builder.write_string(",\"start_angle_deg\":\{start_angle_deg}")
  builder.write_string(",\"points\":[")
  let mut first_pt = true
  for p in points {
    if !first_pt {
      builder.write_char(',')
    }
    first_pt = false
    builder.write_string("[\{p.0},\{p.1},\{p.2}]")
  }
  builder.write_string("]}")
  false
}
