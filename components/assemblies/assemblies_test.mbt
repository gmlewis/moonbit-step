///|
fn close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
fn kit() -> @assemblies.Assembly {
  match @assemblies.metric_hardware_kit(@standards.M4, 20.0) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
}

///|
test "hardware kit has three separate component instances" {
  let assembly = kit()
  assert_eq(assembly.count(), 3)
  let names = assembly.component_names()
  assert_true(names.any(fn(n) { n == "screw" }))
  assert_true(names.any(fn(n) { n == "washer" }))
  assert_true(names.any(fn(n) { n == "nut" }))
  assert_true(assembly.name() == "hardware-kit-M4-20")
}

///|
test "hardware kit placement bounding box" {
  let assembly = kit()
  let (x0, x1, y0, y1, z0, z1) = assembly.bounding_box()
  assert_true(close(x0, -4.5))
  assert_true(close(x1, 4.5))
  assert_true(close(y0, -4.5))
  assert_true(close(y1, 4.5))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 24.0))
}

///|
test "linear pattern repeats a component with increasing offsets" {
  let screw = match @fasteners.iso4762_screw(@standards.M3, 10.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let assembly = @assemblies.Assembly::new(name="row").linear_pattern(
    screw,
    4,
    dx=10.0,
  )
  assert_eq(assembly.count(), 4)
  let (x0, x1, _y0, _y1, _z0, _z1) = assembly.bounding_box()
  assert_true(x0 <= -2.75)
  assert_true(x1 >= 30.0 + 2.75)
}

///|
test "circular pattern distributes instances around z" {
  let screw = match @fasteners.iso4762_screw(@standards.M3, 10.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let assembly = @assemblies.Assembly::new(name="ring").circular_pattern(
    screw, 4, 20.0,
  )
  assert_eq(assembly.count(), 4)
  let (x0, x1, y0, y1, _z0, _z1) = assembly.bounding_box()
  assert_true(x1 > 20.0)
  assert_true(x0 < -20.0)
  assert_true(y1 > 20.0)
  assert_true(y0 < -20.0)
}

///|
test "assembly step preserves one product per materialised solid" {
  let assembly = kit()
  let step = assembly.to_assembly_step()
  let usage = step.split("NEXT_ASSEMBLY_USAGE_OCCURRENCE(").count() - 1
  let nodes = assembly.nodes().length()
  assert_eq(usage, nodes)
  assert_true(step.contains("ITEM_DEFINED_TRANSFORMATION"))
  assert_true(step.contains("CONTEXT_DEPENDENT_SHAPE_REPRESENTATION"))
}

///|
test "flat assembly step keeps separate solids" {
  let assembly = kit()
  let step = assembly.to_step(checked=true)
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
  let solids = step.split("MANIFOLD_SOLID_BREP(").count() - 1
  assert_eq(solids, assembly.nodes().length())
}

///|
test "fastener grid has three components per position" {
  let assembly = match
    @assemblies.fastener_grid_plate(@standards.M4, 16.0, 2, 2, 20.0, 20.0) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  assert_eq(assembly.count(), 12)
  let (x0, x1, _y0, _y1, _z0, _z1) = assembly.bounding_box()
  assert_true(x1 - x0 >= 20.0)
}

///|
test "extrusion frame has four posts and eight rails" {
  let frame = match
    @assemblies.extrusion_frame(
      400.0,
      300.0,
      500.0,
      @profiles.TSlotProfile::generic_2020(),
    ) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  assert_eq(frame.count(), 12)
  let (x0, x1, y0, y1, z0, z1) = frame.bounding_box()
  assert_true(close(x0, -200.0))
  assert_true(close(x1, 200.0))
  assert_true(close(y0, -150.0))
  assert_true(close(y1, 150.0))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 500.0))
}

///|
test "extrusion frame rejects undersized dimensions" {
  assert_true(
    @assemblies.extrusion_frame(
      10.0,
      300.0,
      500.0,
      @profiles.TSlotProfile::generic_2020(),
    )
    is Err(_),
  )
}

///|
test "hardware kit coaxial clearance fit and engagement" {
  for size in [@standards.M3, @standards.M4, @standards.M5] {
    let length = 20.0
    let assembly = match @assemblies.metric_hardware_kit(size, length) {
      Ok(a) => a
      Err(e) => abort(e.message())
    }
    let washer = match @standards.iso7089_size(size) {
      Ok(w) => w
      Err(e) => abort(e.message())
    }
    let nut = match @standards.iso4032_size(size) {
      Ok(n) => n
      Err(e) => abort(e.message())
    }
    let d = size.nominal_diameter_mm()
    // The washer bore clears the nominal screw shank.
    assert_true(washer.inner_diameter_mm > d)
    // The simplified nut bore is the nominal diameter; this is a nominal
    // fit, not an ISO tolerance-class fit.
    let mut washer_z = -1.0
    let mut nut_z = -1.0
    for item in assembly.items() {
      let (rx, ry, rz) = item.placement.to_euler()
      assert_true(close(rx, 0.0))
      assert_true(close(ry, 0.0))
      assert_true(close(rz, 0.0))
      assert_true(close(item.placement.trans.0, 0.0))
      assert_true(close(item.placement.trans.1, 0.0))
      if item.instance_name == "washer" {
        washer_z = item.placement.trans.2
      } else if item.instance_name == "nut" {
        nut_z = item.placement.trans.2
      }
    }
    // Washer top face meets the head underside at z = length.
    assert_true(close(washer_z + washer.thickness_mm, length))
    // The nut is near the free end and the screw passes fully through it.
    assert_true(close(nut_z, 2.0))
    assert_true(nut_z + nut.height_mm < length)
  }
}

///|
test "hardware kit envelope overlap is a nested-bore false positive" {
  // The screw shank passes through the washer and nut bores. The OBB envelope
  // necessarily reports overlap because the bore is a hole; this test records
  // the limitation so a future shape-aware test can replace it.
  let assembly = kit()
  assert_true(!assembly.collisions().is_empty())
  assert_true(assembly.is_connected())
}
