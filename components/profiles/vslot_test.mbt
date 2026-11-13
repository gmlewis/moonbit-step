///|
fn vslot_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
test "V-Slot 2020 section dimensions and analytic geometry" {
  let profile = @profiles.VSlotProfile::vslot_2020()
  assert_eq(profile.designation(), "V-Slot-2020")
  assert_eq(profile.slot_count(), 4)
  let (w, h) = profile.size()
  assert_true(vslot_close(w, 20.0, 1.0e-12))
  assert_true(vslot_close(h, 20.0, 1.0e-12))
  let part = match @profiles.vslot_extrusion(profile, 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(vslot_close(x0, -10.0, 1.0e-9))
  assert_true(vslot_close(x1, 10.0, 1.0e-9))
  assert_true(vslot_close(y0, -10.0, 1.0e-9))
  assert_true(vslot_close(y1, 10.0, 1.0e-9))
  assert_true(vslot_close(z0, 0.0, 1.0e-9))
  assert_true(vslot_close(z1, 100.0, 1.0e-9))
  let layer = part.layers()[0]
  let inventory = layer.shape.surface_inventory()
  // 64 straight boundary lines plus two caps; four analytic corner arcs and
  // four arcs forming the core bore. The in-memory inventory counts each arc
  // band; the STEP compiler merges the full bore loop into one cylinder.
  assert_eq(inventory.plane, 66)
  assert_eq(inventory.cylinder, 8)
  let volume = match layer.shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  // 171.7557 mm^2 x 100 mm; the published section area is 171.5 mm^2.
  assert_true(vslot_close(volume, 17175.57, 5.0))
  let section = match layer.shape.section_at_local(50.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(vslot_close(section.area_mm2, 171.7557, 0.05))
  assert_true(vslot_close(section.perimeter_mm, 160.545, 0.02))
}

///|
test "V-Slot 2040 section has six slots, two bores, and a central channel" {
  let profile = @profiles.VSlotProfile::vslot_2040()
  assert_eq(profile.slot_count(), 6)
  assert_eq(profile.holes().length(), 3)
  let part = match @profiles.vslot_extrusion(profile, 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, _z0, _z1) = part.bounding_box()
  assert_true(vslot_close(x0, -10.0, 1.0e-9))
  assert_true(vslot_close(x1, 10.0, 1.0e-9))
  assert_true(vslot_close(y0, -20.0, 1.0e-9))
  assert_true(vslot_close(y1, 20.0, 1.0e-9))
  let layer = part.layers()[0]
  let inventory = layer.shape.surface_inventory()
  // 94 outer lines + 12 channel lines + two caps; four corner arcs and eight
  // bore arcs.
  assert_eq(inventory.plane, 108)
  assert_eq(inventory.cylinder, 12)
  let volume = match layer.shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(vslot_close(volume, 30051.86, 5.0))
  let section = match layer.shape.section_at_local(50.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(vslot_close(section.area_mm2, 300.5186, 0.05))
}

///|
test "V-Slot geometry is not the generic T-slot envelope" {
  let vslot = @profiles.VSlotProfile::vslot_2020()
  let tslot = @profiles.TSlotProfile::generic_2020()
  // The V-Slot mouth is wider than its neck; the generic T-slot has no V lips.
  assert_true(vslot.slot_mouth_mm > vslot.slot_neck_mm)
  assert_true(tslot.slot_width_mm == 6.0)
  assert_true(vslot.slot_neck_mm > tslot.slot_width_mm)
}

///|
test "V-Slot custom validation rejects impossible sections" {
  // Neck wider than the mouth.
  assert_true(
    @profiles.VSlotProfile::custom(
      name="bad",
      width_mm=20.0,
      height_mm=20.0,
      slot_mouth_mm=6.0,
      slot_neck_mm=7.0,
    )
    is Err(_),
  )
  // Height not a whole number of cells.
  assert_true(
    @profiles.VSlotProfile::custom(name="bad", width_mm=20.0, height_mm=30.0)
    is Err(_),
  )
  // Three- and four-cell sections are not modelled yet.
  assert_true(
    @profiles.VSlotProfile::custom(name="bad", width_mm=20.0, height_mm=60.0)
    is Err(_),
  )
  // Core bore larger than the available floor.
  assert_true(
    @profiles.VSlotProfile::custom(
      name="bad",
      width_mm=20.0,
      height_mm=20.0,
      core_bore_diameter_mm=12.0,
    )
    is Err(_),
  )
  // Zero length is rejected by the extrusion builder.
  assert_true(
    @profiles.vslot_extrusion(@profiles.VSlotProfile::vslot_2020(), 0.0)
    is Err(_),
  )
}
