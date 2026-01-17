///|
/// 12-bifilar-electromagnet
///
/// Usage (stdout):
///   moon run --target native examples/12-bifilar-electromagnet -- > bifilar-electromagnet.step
///
/// Usage (write file):
///   moon run --target native examples/12-bifilar-electromagnet -- -o bifilar-electromagnet.step
async fn main {
  guard parse_params() is Some(params) else { return }

  //
  if params.report {
    report_electrical_geometry(params)
  }

  //
  match params.export_centerlines_path {
    None => ()
    Some(path) => export_helix_centerlines_json(params, path)
  }

  //
  match params.export_conductor_network_path {
    None => ()
    Some(path) => export_conductor_network_json(params, path)
  }

  //
  let mut design = @cad.Design::new(
    name="bifilar-electromagnet",
    snapping=params.snapping,
  )
  let wire_nodes = []
  let support_nodes = []
  // Add coil pairs if requested
  if !params.nocoil {
    for pair_num in 1..=params.num_pairs {
      if params.debug {
        @cli.eprintln("Generating pair #\{pair_num} of \{params.num_pairs}")
      }
      let coil_pair = make_coil_pair(pair_num~, params~)
      wire_nodes..push(coil_pair.0).push(coil_pair.1)
    }
  }
  // Add cage if requested
  if !params.nocage {
    let (radius, height) = coil_turn_dimensions(params.num_pairs, params)
    let (wires, support) = make_bfem_cage(
      size=(radius, radius, height),
      params~,
    )
    wire_nodes.append(wires)
    support_nodes.append(support)
  }
  if params.union {
    design = design.add(@cad.union_all(wire_nodes, name="wires"))
    design = design.add(@cad.union_all(support_nodes, name="support"))
  } else {
    for node in wire_nodes {
      design = design.add(node)
    }
    for node in support_nodes {
      design = design.add(node)
    }
  }
  if !params.nostep {
    if params.blend_path is Some(blend_path) {
      design.create_blender_file(blend_path)
    } else if params.bpy_path is Some(_) {
      design.write_blender_python(params.bpy_path)
    } else {
      design.write_step(params.out_path)
    }
  }
}

///|
fn make_coil_pair(
  pair_num~ : Int,
  params~ : Params,
) -> (@cad.SceneNode, @cad.SceneNode) {
  let delta_z = (params.wire_gap + params.wire_width) /
    (params.num_pairs.to_double() - 1)
  let new_pos = (
    params.pos.0,
    params.pos.1,
    params.pos.2 + (pair_num - 1).to_double() * delta_z,
  )
  let params = { ..params, pos: new_pos }

  //
  let start_angle = 180.0 *
    (pair_num.to_double() - 1) /
    params.num_pairs.to_double()
  // Create the two helices for the bifilar coil pair
  let color = @cad.Rgb::red()
  let coil1 = make_coil(start_angle, pair_num~, params~, color~).with_name(
    "bfem:coil:red:pair-\{pair_num}",
  )
  let color = @cad.Rgb::green()
  let coil2 = make_coil(start_angle + 180, pair_num~, params~, color~).with_name(
    "bfem:coil:green:pair-\{pair_num}",
  )
  return (coil1, coil2)
}

///|
/// coil_turn_dimensions returns the helix path X/Y radius and Z rise per turn
/// for the given coil pair index (1-based).
fn coil_turn_dimensions(pair_num : Int, params : Params) -> (Double, Double) {
  let hw = params.wire_width / 2.0
  let radius = params.inner_diam / 2.0 +
    hw +
    (pair_num - 1).to_double() * (params.wire_gap + params.wire_width)
  let height = 2.0 * (params.wire_width + params.wire_gap)
  return (radius, height)
}

///|
fn square_wire_profile(hw : Double) -> @cad.SweepProfile {
  let wire_pts = [
    (-hw, 0.0, -hw),
    (hw, 0.0, -hw),
    (hw, 0.0, hw),
    (-hw, 0.0, hw),
  ]
  @cad.SweepProfile::new(wire_pts)
}

///|
fn make_coil(
  start_angle : Double,
  pair_num~ : Int,
  params~ : Params,
  color? : @cad.Rgb = @cad.Rgb::red(),
) -> @cad.SceneNode {
  let hw = params.wire_width / 2.0
  let (radius, height) = coil_turn_dimensions(pair_num, params)
  let helix_path = @cad.helix_path(
    pos=params.pos,
    size_per_turn=(radius, radius, height),
    num_turns=params.vert_turns,
    num_segs_per_turn=params.num_segs,
    start_angle~,
  )
  let wire_profile = square_wire_profile(hw)
  let coil_shape = @cad.SweptProfile::new(path=helix_path, profile=wire_profile).with_color(
    color,
  )
  coil_shape
}
