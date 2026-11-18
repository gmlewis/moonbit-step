///|
fn unwrap_pvc_size(
  trade : String,
  schedule~ : @pvc.PvcSchedule = Schedule40,
) -> @pvc.PvcSize {
  match @pvc.pvc_size(trade, schedule~) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
}

///|
fn unwrap_pvc_comp(
  res : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match res {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
fn pvc_close(a : Double, b : Double, tol~ : Double = 1.0e-5) -> Bool {
  (a - b).abs() <= tol
}

///|
fn pvc_close_vec(a : @cad.Vec3, b : @cad.Vec3, tol~ : Double = 1.0e-4) -> Bool {
  pvc_close(a.0, b.0, tol~) &&
  pvc_close(a.1, b.1, tol~) &&
  pvc_close(a.2, b.2, tol~)
}

///|
test "pvc_size covers all supported ASTM D1785 IPS trade sizes and schedules" {
  let sizes = @pvc.pvc_trade_sizes()
  assert_eq(sizes.length(), 6)
  for trade in sizes {
    let s40 = unwrap_pvc_size(trade, schedule=Schedule40)
    let s80 = unwrap_pvc_size(trade, schedule=Schedule80)
    // ASTM D1785 IPS: Sch 40 and Sch 80 share identical OD so fittings interchange.
    assert_true(pvc_close(s40.pipe_od_mm, s80.pipe_od_mm))
    assert_true(s80.pipe_wall_mm > s40.pipe_wall_mm)
    assert_true(s80.pipe_id_mm < s40.pipe_id_mm)
    assert_true(s40.socket_bore_mm > s40.pipe_od_mm)
    assert_true(s40.socket_outer_mm > s40.socket_bore_mm)
    assert_true(s40.socket_depth_mm > 0.0)
    assert_true(s40.center_to_seat_90_mm > s40.center_to_seat_45_mm)
  }
  // Verify exact published 3/4 in IPS OD = 1.050 in = 26.670 mm.
  let s34 = unwrap_pvc_size("3/4")
  assert_true(pvc_close(s34.pipe_od_mm, 26.670))
  assert_true(@pvc.pvc_size("5/8") is Err(@common.InvalidSize(_)))
  assert_true(
    @pvc.pvc_size("3/4", bore_clearance_mm=-0.1)
    is Err(@common.InvalidParameter(_)),
  )
}

///|
test "pvc_pipe exports closed shell STEP and valid volume" {
  let s34 = unwrap_pvc_size("3/4", schedule=Schedule40)
  let pipe = unwrap_pvc_comp(@pvc.pvc_pipe(s34, 150.0, detail=Detailed))
  let (x0, x1, y0, y1, z0, z1) = pipe.bounding_box()
  let r_out = s34.pipe_od_mm / 2.0
  assert_true(pvc_close(x0, -r_out))
  assert_true(pvc_close(x1, r_out))
  assert_true(pvc_close(y0, -r_out))
  assert_true(pvc_close(y1, r_out))
  assert_true(pvc_close(z0, 0.0))
  assert_true(pvc_close(z1, 150.0))
  let step = pipe.to_step()
  assert_true(step.contains("CLOSED_SHELL("))
  assert_true(pipe.features().has_modeled("end-chamfer"))
  assert_true(@pvc.pvc_pipe(s34, 0.0) is Err(@common.InvalidDimension(_)))
}

///|
test "coupling, cap, and reducer_coupling build closed solids with internal pipe stops" {
  let s1 = unwrap_pvc_size("1")
  let s34 = unwrap_pvc_size("3/4")
  let coup = unwrap_pvc_comp(@pvc.coupling(s34, detail=Detailed))
  let cap_part = unwrap_pvc_comp(@pvc.cap(s34, detail=Detailed))
  let red = unwrap_pvc_comp(@pvc.reducer_coupling(s1, s34, detail=Detailed))
  for part in [coup, cap_part, red] {
    let step = part.to_step()
    assert_true(step.contains("CLOSED_SHELL("))
    let inv = part.layers()[0].shape.surface_inventory()
    assert_true(inv.cone >= 1)
  }
  assert_true(
    @pvc.reducer_coupling(s34, s1) is Err(@common.InvalidParameter(_)),
  )
}

///|
test "elbow_90 and elbow_45 build smooth swept bends with valid ports" {
  let s34 = unwrap_pvc_size("3/4")
  let e90 = unwrap_pvc_comp(@pvc.elbow_90(s34, detail=Detailed))
  let e45 = unwrap_pvc_comp(@pvc.elbow_45(s34, detail=Detailed))
  assert_true(e90.to_step().contains("B_SPLINE_SURFACE_WITH_KNOTS("))
  assert_true(e45.to_step().contains("B_SPLINE_SURFACE_WITH_KNOTS("))
  assert_true(e90.connector("socket-a") is Ok(_))
  assert_true(e90.connector("socket-b") is Ok(_))
  assert_true(e45.connector("socket-b") is Ok(_))
}

///|
test "tee, cross, corner_3way, four_way_tee, five_way, and flange assemble cleanly" {
  let s34 = unwrap_pvc_size("3/4")
  let tee = unwrap_pvc_comp(@pvc.tee(s34))
  let cross = unwrap_pvc_comp(@pvc.cross(s34))
  let c3 = unwrap_pvc_comp(@pvc.corner_3way(s34))
  let f4 = unwrap_pvc_comp(@pvc.four_way_tee(s34))
  let f5 = unwrap_pvc_comp(@pvc.five_way(s34))
  let fl = unwrap_pvc_comp(@pvc.flange(s34, detail=Detailed))
  assert_eq(tee.layers().length(), 3)
  assert_eq(cross.layers().length(), 4)
  assert_eq(c3.layers().length(), 4)
  assert_eq(f4.layers().length(), 5)
  assert_eq(f5.layers().length(), 6)
  assert_eq(fl.layers().length(), 2)
  assert_true(fl.connector("mount-hole-4") is Ok(_))
  for part in [tee, cross, c3, f4, f5, fl] {
    assert_true(part.to_step().contains("CLOSED_SHELL("))
  }
}

///|
test "snap_connectors seats pvc_pipe ends flush inside elbow_90 and coupling sockets" {
  let s34 = unwrap_pvc_size("3/4")
  let pipe = unwrap_pvc_comp(@pvc.pvc_pipe(s34, 120.0))
  let coup = unwrap_pvc_comp(@pvc.coupling(s34))
  let e90 = unwrap_pvc_comp(@pvc.elbow_90(s34))
  let c_sock_b = match coup.connector("socket-b") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let p_end_a = match pipe.connector("end-a") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (snapped_a, _) = @common.snap_connectors(c_sock_b, p_end_a)
  // Pipe z = 0 sits on seat (0, 0, +2.0); pipe z = 120 extends to +122.0.
  assert_true(
    pvc_close_vec(snapped_a.apply_point((0.0, 0.0, 0.0)), (0.0, 0.0, 2.0)),
  )
  assert_true(
    pvc_close_vec(snapped_a.apply_point((0.0, 0.0, 120.0)), (0.0, 0.0, 122.0)),
  )
  let e_sock_b = match e90.connector("socket-b") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let p_end_b = match pipe.connector("end-b") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (snapped_e, _) = @common.snap_connectors(e_sock_b, p_end_b)
  let lay = s34.center_to_seat_90_mm
  assert_true(
    pvc_close_vec(snapped_e.apply_point((0.0, 0.0, 120.0)), (lay, 0.0, 0.0)),
  )
  assert_true(
    pvc_close_vec(
      snapped_e.apply_point((0.0, 0.0, 0.0)),
      (lay + 120.0, 0.0, 0.0),
    ),
  )
}

///|
test "pvc_box_frame_cut_list and pvc_box_frame_assembly compute exact frame spans" {
  let s12 = unwrap_pvc_size("1/2")
  let items = match @pvc.pvc_box_frame_cut_list(300.0, 200.0, 150.0, s12) {
    Ok(i) => i
    Err(e) => abort(e.message())
  }
  assert_eq(items.length(), 4)
  assert_eq(items[0].count, 4)
  assert_true(
    pvc_close(items[0].length_mm, 300.0 - 2.0 * s12.center_to_seat_90_mm),
  )
  let frame = unwrap_pvc_comp(
    @pvc.pvc_box_frame_assembly(300.0, 200.0, 150.0, s12),
  )
  let (x0, x1, y0, y1, z0, z1) = frame.bounding_box()
  let half_out = s12.socket_outer_mm / 2.0
  assert_true(pvc_close(x0, -half_out, tol=0.05))
  assert_true(pvc_close(x1, 300.0 + half_out, tol=0.05))
  assert_true(pvc_close(y0, -half_out, tol=0.05))
  assert_true(pvc_close(y1, 200.0 + half_out, tol=0.05))
  assert_true(pvc_close(z0, -half_out, tol=0.05))
  assert_true(pvc_close(z1, 150.0 + half_out, tol=0.05))
}
