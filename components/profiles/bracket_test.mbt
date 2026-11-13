///|
fn bracket_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn bracket_has(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
fn bracket_connector(
  part : @common.Component,
  name : String,
) -> @common.MateConnector {
  for connector in part.connectors() {
    if connector.name == name {
      return connector
    }
  }
  abort("missing connector " + name)
}

///|
test "corner bracket matches the 20-series reference boundary" {
  let part = match @profiles.vslot_corner_bracket() {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(bracket_close(x0, -10.0, 1.0e-6))
  assert_true(bracket_close(x1, 10.0, 1.0e-6))
  assert_true(bracket_close(y0, -10.0, 1.0e-6))
  assert_true(bracket_close(y1, 10.0, 1.0e-6))
  assert_true(bracket_close(z0, 0.0, 1.0e-6))
  assert_true(bracket_close(z1, 20.0, 1.0e-6))
  let mut volume = 0.0
  for layer in part.layers() {
    volume += match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort(e.message())
    }
  }
  // Two 3 mm slotted legs plus two 3 mm 45-degree gussets: 2516.95 mm^3.
  assert_true(bracket_close(volume, 2516.95, 0.05))
  assert_true(part.layers().length() == 4)
}

///|
test "corner bracket exposes faces, slots, and the inner-corner datum" {
  let part = match @profiles.vslot_corner_bracket() {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  for
    name in ["base-face", "side-face", "base-slot", "side-slot", "inner-corner"] {
    if !bracket_has(part, name) {
      abort("corner bracket is missing connector " + name)
    }
  }
  let base_slot = bracket_connector(part, "base-slot")
  assert_true(base_slot.kind is @common.MateKind::ProfileSlot)
  assert_true(bracket_close(base_slot.placement.trans.1, -1.0, 1.0e-9))
  match base_slot.diameter_mm {
    Some(d) => assert_true(bracket_close(d, 5.5, 1.0e-9))
    None => fail("expected a slot width")
  }
  let side_slot = bracket_connector(part, "side-slot")
  assert_true(bracket_close(side_slot.placement.trans.2, 11.0, 1.0e-9))
  let base_face = bracket_connector(part, "base-face")
  assert_true(base_face.axis.2 < -0.99)
  let side_face = bracket_connector(part, "side-face")
  assert_true(side_face.axis.1 > 0.99)
  assert_true(
    bracket_connector(part, "inner-corner").kind is @common.MateKind::Datum,
  )
}

///|
test "corner bracket rejects impossible dimensions" {
  assert_true(@profiles.vslot_corner_bracket(thickness_mm=10.0) is Err(_))
  assert_true(
    @profiles.vslot_corner_bracket(gusset_thickness_mm=12.0) is Err(_),
  )
  assert_true(@profiles.vslot_corner_bracket(slot_length_mm=18.0) is Err(_))
  assert_true(
    @profiles.vslot_corner_bracket(slot_width_mm=5.5, slot_length_mm=5.0)
    is Err(_),
  )
  assert_true(@profiles.vslot_corner_bracket(leg_mm=0.0) is Err(_))
}

///|
test "corner bracket scales with a rectangular leg and width" {
  let part = match @profiles.vslot_corner_bracket(leg_mm=30.0, width_mm=20.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(bracket_close(x1 - x0, 20.0, 1.0e-6))
  assert_true(bracket_close(y1 - y0, 30.0, 1.0e-6))
  assert_true(bracket_close(z1 - z0, 30.0, 1.0e-6))
  let mut volume = 0.0
  for layer in part.layers() {
    volume += match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort(e.message())
    }
  }
  assert_true(bracket_close(volume, 4856.95, 0.05))
  // Two slots plus four gusset faces still expose the expected connectors.
  assert_true(bracket_has(part, "base-slot"))
  assert_true(bracket_has(part, "side-slot"))
}
