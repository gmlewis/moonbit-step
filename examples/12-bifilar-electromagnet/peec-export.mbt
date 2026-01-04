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
/// Export a *single* series conductor path with explicit IN/OUT terminals.
///
/// This is intended to represent the claimed single continuous wire between
/// `bfem:exit-wire:green` (IN) and `bfem:exit-wire:red` (OUT).
///
/// Units: millimeters.
async fn export_conductor_network_json(
  params : Params,
  out_path : String,
) -> Unit {
  let (radius, height) = coil_turn_dimensions(params.num_pairs, params)
  let (in_base, out_base, in_term, out_term) = compute_exit_wire_terminals(
    (radius, radius, height),
    params,
  )

  // Build a single polyline by stitching together helix centerlines with
  // explicit straight-line jump segments.
  let series = Array::new()

  // Start at IN terminal (top of the green exit wire) then go down to the base.
  push_point(series, in_term)
  push_point(series, in_base)

  // Precompute all helix point arrays so we can stitch deterministically.
  let delta_z = (params.wire_gap + params.wire_width) /
    (params.num_pairs.to_double() - 1)

  // We build a serpentine through the stacked pairs:
  //   green(top->bottom) -> jump -> red(bottom->top) -> jump to next layer
  // ending back at OUT base.
  //
  // NOTE: This export defines the *intended* single series path for solver
  // workflows; it does not attempt to infer topology from the STEP.
  for i in 0..<params.num_pairs {
    let pair_num = params.num_pairs - i
    let z_off = (pair_num - 1).to_double() * delta_z
    let local_pos = (params.pos.0, params.pos.1, params.pos.2 + z_off)
    let local_params = { ..params, pos: local_pos }
    let start_angle = 180.0 *
      (pair_num.to_double() - 1) /
      params.num_pairs.to_double()
    let (r, height_per_turn) = coil_turn_dimensions(pair_num, local_params)
    let path_red = @cad.helix_path(
      pos=local_params.pos,
      size_per_turn=(r, r, height_per_turn),
      num_turns=local_params.vert_turns,
      num_segs_per_turn=local_params.num_segs,
      start_angle~,
    )
    let path_green = @cad.helix_path(
      pos=local_params.pos,
      size_per_turn=(r, r, height_per_turn),
      num_turns=local_params.vert_turns,
      num_segs_per_turn=local_params.num_segs,
      start_angle=start_angle + 180,
    )
    let (green_top_to_bottom, red_bottom_to_top) = orient_bifilar_pair(
      path_green.points,
      path_red.points,
    )

    // Jump from current series end to green top.
    push_point(series, green_top_to_bottom[0])

    // Append green helix (skip duplicate start point if already present).
    append_polyline(series, green_top_to_bottom)

    // Jump from green bottom to red bottom.
    push_point(series, red_bottom_to_top[0])

    // Append red helix.
    append_polyline(series, red_bottom_to_top)

    // If there is an inner layer remaining, jump from red top to the next
    // layer's green top will happen on next iteration (by pushing that point).
  }

  // End at OUT base and then extend to the OUT terminal top.
  push_point(series, out_base)
  push_point(series, out_term)

  // Emit JSON.
  let builder = StringBuilder::new()
  builder.write_string("{\"schema\":\"bfem:conductor-network:v1\"")
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
  builder.write_string(",\"terminals\":[")
  emit_terminal_json(builder, true, "IN", "bfem:exit-wire:green", in_term)
  emit_terminal_json(builder, false, "OUT", "bfem:exit-wire:red", out_term)
  builder.write_string("]")
  builder.write_string(",\"paths\":[")
  builder.write_string("{\"name\":\"bfem:conductor:series\",\"points\":[")
  let mut first_pt = true
  for p in series {
    if !first_pt {
      builder.write_char(',')
    }
    first_pt = false
    builder.write_string("[\{p.0},\{p.1},\{p.2}]")
  }
  builder.write_string("]}")
  builder.write_string("]}")
  @fs.write_file(
    out_path,
    @encoding/utf8.encode(builder.to_string()),
    create=0o644,
    truncate=true,
  ) catch {
    err => {
      @cli.eprintln("error: failed to write conductor network JSON: \{err}")
      abort("")
    }
  }
}

///|
fn push_point(dst : Array[Vec3], p : Vec3) -> Unit {
  if dst.length() == 0 {
    dst.push(p)
    return
  }
  let last = dst[dst.length() - 1]
  if last != p {
    dst.push(p)
  }
}

///|
fn emit_terminal_json(
  builder : StringBuilder,
  first : Bool,
  label : String,
  name : String,
  p : Vec3,
) -> Unit {
  if !first {
    builder.write_char(',')
  }
  builder.write_string("{\"label\":\"")
  builder.write_string(label)
  builder.write_string("\",\"name\":\"")
  builder.write_string(name)
  builder.write_string("\",\"point\":[\{p.0},\{p.1},\{p.2}]}")
}

///|
fn append_polyline(dst : Array[Vec3], src : Array[Vec3]) -> Unit {
  if src.length() == 0 {
    return
  }
  // Avoid repeating the first point if it matches the last.
  if dst.length() > 0 {
    let last = dst[dst.length() - 1]
    let first = src[0]
    if last == first {
      for i in 1..<src.length() {
        dst.push(src[i])
      }
      return
    }
  }
  for p in src {
    dst.push(p)
  }
}

///|
/// Orient a bifilar pair such that:
/// - green runs from top->bottom
/// - red runs from bottom->top
fn orient_bifilar_pair(
  green : Array[Vec3],
  red : Array[Vec3],
) -> (Array[Vec3], Array[Vec3]) {
  let g0 = green[0]
  let g1 = green[green.length() - 1]
  let r0 = red[0]
  let r1 = red[red.length() - 1]
  let green_top_to_bottom = if g0.2 >= g1.2 {
    green
  } else {
    reverse_points(green)
  }
  let red_bottom_to_top = if r0.2 <= r1.2 { red } else { reverse_points(red) }
  (green_top_to_bottom, red_bottom_to_top)
}

///|
fn reverse_points(points : Array[Vec3]) -> Array[Vec3] {
  let out = Array::new(capacity=points.length())
  let n = points.length()
  for i in 0..<n {
    out.push(points[n - 1 - i])
  }
  out
}

///|
/// Compute exit-wire base and terminal points using the same math used by
/// bfem-cage for the final (outermost) pair.
fn compute_exit_wire_terminals(
  size : Vec3,
  params : Params,
) -> (Vec3, Vec3, Vec3, Vec3) {
  // Mirror make_cage_context calculations (kept local to avoid geometry deps).
  let npairs = params.num_pairs
  let num_pairs = npairs.to_double()
  let lower_z = params.pos.2 - params.wire_width / 2
  let coil_height = 2.0 *
    params.vert_turns *
    (params.wire_width + params.wire_gap) +
    params.wire_width
  let extrude_height = coil_height + params.wire_gap + params.wire_width
  let rail_angle_delta = @math.PI / num_pairs
  let inner_radius = size.0 + params.wire_width / 2 + params.wire_gap
  let outer_radius = inner_radius + params.radial_thickness
  let outer_dtheta = @math.asin(params.wire_gap / (2 * outer_radius))
  let delta_z = (params.wire_gap + params.wire_width) / (num_pairs - 1)
  let max_axial_connector_top_zs = extrude_height +
    lower_z +
    (num_pairs - 1) * delta_z

  // Use the final (outermost) i.
  let i = npairs - 1
  let i_d = i.to_double()
  let rotation = -@math.PI * i_d / num_pairs
  let line_length = (num_pairs - i_d) * (params.wire_width + params.wire_gap)
  let connector_radius = inner_radius - line_length
  let connector_dtheta = @math.asin(params.wire_gap / (2 * connector_radius))
  let top_angle = rotation - connector_dtheta

  // This matches bfem-cage: top_helix_z derived from the pair Z.
  let z_layer = lower_z + i_d * delta_z + params.wire_width
  let top_helix_z = z_layer + coil_height - 2 * params.wire_width

  // Inner flat-top output connector polygon.
  let angle_diff = rail_angle_delta - 2 * outer_dtheta
  let sx4 = params.pos.0 + connector_radius * @math.cos(top_angle + @math.PI)
  let sy4 = params.pos.1 + connector_radius * @math.sin(top_angle + @math.PI)
  let sx1 = params.pos.0 +
    connector_radius * @math.cos(top_angle + @math.PI - angle_diff)
  let sy1 = params.pos.1 +
    connector_radius * @math.sin(top_angle + @math.PI - angle_diff)
  let ew_inner_radius = connector_radius -
    0.6 * params.exit_wire_separation -
    params.exit_wire_diameter
  let s2 = vertex_at(
    center=(params.pos.0, params.pos.1),
    radius=ew_inner_radius,
    angle=top_angle + @math.PI,
  )
  let s3 = vertex_at(
    center=(params.pos.0, params.pos.1),
    radius=ew_inner_radius,
    angle=top_angle + @math.PI - angle_diff,
  )
  let polygon = [(sx4, sy4), (sx1, sy1), s3, s2]
  let inner_wire_post_center = center_of_face(polygon)
  let mut inner_wire_pos = inner_wire_post_center
  let outer_wire_radius = (inner_radius + outer_radius) / 2
  let outer_wire_dtheta = @math.asin(params.wire_gap / (2 * outer_wire_radius))
  let outer_wire_start_angle = 0.0
  let outer_wire_end_angle = rail_angle_delta - 2 * outer_wire_dtheta
  let outer_wire_post_center = vertex_at(
    center=(params.pos.0, params.pos.1),
    radius=outer_wire_radius,
    angle=(outer_wire_end_angle - outer_wire_start_angle) / 2,
  )
  let mut outer_wire_pos = outer_wire_post_center
  let centers_distance = vector_length(
    outer_wire_post_center, inner_wire_post_center,
  )
  if centers_distance < params.exit_wire_separation {
    let pa = inner_wire_post_center
    let va = (polygon[3].0, polygon[3].1)
    let pb = outer_wire_post_center
    let vb = vertex_at(
      center=(params.pos.0, params.pos.1),
      radius=(inner_radius + outer_radius) / 2,
      angle=outer_wire_start_angle,
    )
    let f1 = fn(t) { (pa.0 + t * (va.0 - pa.0), pa.1 + t * (va.1 - pa.1)) }
    let f2 = fn(t) { (pb.0 + t * (vb.0 - pb.0), pb.1 + t * (vb.1 - pb.1)) }
    let d = params.exit_wire_separation
    let t = solve_for_t(d, fn(t) { vector_length(f1(t), f2(t)) })
    inner_wire_pos = f1(t)
    outer_wire_pos = f2(t)
  }
  let flat_top_height = 2.5 * params.wire_width + params.back_thickness
  let in_base = (
    inner_wire_pos.0,
    inner_wire_pos.1,
    top_helix_z + flat_top_height,
  )
  let out_base = (
    outer_wire_pos.0,
    outer_wire_pos.1,
    top_helix_z + flat_top_height,
  )
  let in_term = (in_base.0, in_base.1, in_base.2 + params.connector_length)
  let out_term = (out_base.0, out_base.1, out_base.2 + params.connector_length)

  // Keep the max_axial_connector_top_zs calculation “used” to avoid drift vs
  // the geometry code if it is later incorporated into the stitching logic.
  let _ = max_axial_connector_top_zs
  (in_base, out_base, in_term, out_term)
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
