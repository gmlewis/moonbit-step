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
    // The nut sits at the free end (z = 0) and the screw passes fully through
    // it. A fixed 2 mm offset (the old behaviour) overlapped the washer and
    // head for short valid screws.
    assert_true(close(nut_z, 0.0))
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

///|
test "bolted joint is a connected mixed-family assembly" {
  let assembly = match
    @assemblies.bolted_joint(@standards.M4, 40.0, 30.0, 5.0) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  assert_eq(assembly.count(), 5)
  let (x0, x1, y0, y1, z0, z1) = assembly.bounding_box()
  assert_true(close(x0, -20.0))
  assert_true(close(x1, 20.0))
  assert_true(close(y0, -15.0))
  assert_true(close(y1, 15.0))
  // Nut height 3.2 (below z = 0); head top = 2*5 + 0.8 + 4.0.
  assert_true(close(z0, -3.2))
  assert_true(close(z1, 14.8))
  assert_true(assembly.is_connected())
  assert_true(!assembly.contacts().is_empty())
  // The OBB envelopes report the shank inside the plate, washer, and nut
  // bores as overlaps. This is the documented nested-bore false positive; it
  // is not claimed as a shape-aware clearance proof.
  assert_true(!assembly.collisions().is_empty())
  let step = assembly.to_step(checked=true)
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
}

///|
test "bolted joint part schedule groups identical parts" {
  let assembly = match
    @assemblies.bolted_joint(@standards.M4, 40.0, 30.0, 5.0) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  let schedule = assembly.schedule()
  // Two identical plates, one screw, one washer, one nut.
  assert_eq(schedule.length(), 4)
  let mut total = 0
  let mut plate_quantity = 0
  for entry in schedule {
    total = total + entry.quantity
    if entry.part_name.contains("plate") {
      plate_quantity = entry.quantity
    }
  }
  assert_eq(total, 5)
  assert_eq(plate_quantity, 2)
  let text = assembly.schedule_text()
  assert_true(text.contains("2 x"))
  assert_true(text.contains("ISO 4762"))
}

///|
test "plate with hole rejects an oversized hole" {
  assert_true(@assemblies.plate_with_hole(20.0, 20.0, 3.0, 25.0) is Err(_))
  assert_true(@assemblies.plate_with_hole(20.0, 20.0, 3.0, 6.0) is Ok(_))
}

///|
test "disconnected instances do not depend on insertion order" {
  let plate = match @assemblies.plate_with_hole(40.0, 30.0, 5.0, 4.4) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let screw = match @fasteners.iso4762_screw(@standards.M4, 20.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  // The floating screw is inserted first. Two stacked plates touch at z = 5.
  let assembly = @assemblies.Assembly::new(name="floating-first")
    .add(
      screw,
      placement=@common.Placement::translation(100.0, 0.0, 0.0),
      instance_name="floating-screw",
    )
    .add(plate, instance_name="plate-bottom")
    .add(
      plate,
      placement=@common.Placement::translation(0.0, 0.0, 5.0),
      instance_name="plate-top",
    )
  let floating = assembly.disconnected_instances()
  assert_eq(floating.length(), 1)
  assert_true(floating[0] == "floating-screw")
  assert_false(assembly.is_connected())
}

///|
fn item_z_span(
  assembly : @assemblies.Assembly,
  instance_name : String,
) -> (Double, Double) {
  for item in assembly.items() {
    if item.instance_name == instance_name {
      let (_, _, _, _, z0, z1) = item.component.bounding_box()
      let tz = item.placement.trans.2
      return (tz + z0, tz + z1)
    }
  }
  abort("missing assembly item: " + instance_name)
}

///|
test "hardware kit nut at the free end clears the washer for a short screw" {
  let assembly = match @assemblies.metric_hardware_kit(@standards.M2, 3.0) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  let (nut0, nut1) = item_z_span(assembly, "nut")
  let (washer0, _washer1) = item_z_span(assembly, "washer")
  assert_true(close(nut0, 0.0))
  // M2 nut height 1.6, washer bottom 3.0 - 0.3 = 2.7.
  assert_true(close(nut1, 1.6))
  assert_true(nut1 <= washer0)
}

///|
test "fastener grid nut sits at the free end for a short screw" {
  let assembly = match
    @assemblies.fastener_grid_plate(@standards.M4, 6.0, 1, 1, 20.0, 20.0) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  let (nut0, nut1) = item_z_span(assembly, "nut-1")
  let (washer0, _washer1) = item_z_span(assembly, "washer-1")
  assert_true(close(nut0, -6.0))
  // M4 nut height 3.2; washer spans -0.8 .. 0.
  assert_true(close(nut1, -2.8))
  assert_true(nut1 <= washer0)
}

///|
test "collisions honours a declared interference policy" {
  let assembly = kit()
  let policy = @collision.ContactPolicy::none().permit("screw", "washer")
  let collisions = assembly.collisions(policy~)
  let still_reported = collisions.any(fn(r) {
    (r.instance_a == "screw" && r.instance_b == "washer") ||
    (r.instance_a == "washer" && r.instance_b == "screw")
  })
  assert_false(still_reported)
  let fits = assembly.interference_fits(policy~)
  assert_true(
    fits.any(fn(r) {
      (r.instance_a == "screw" && r.instance_b == "washer") ||
      (r.instance_a == "washer" && r.instance_b == "screw")
    }),
  )
}

///|
fn through_bore_deviation(component : @common.Component) -> Double {
  for a in component.features().approximated {
    if a.feature == "through-bore" {
      return a.deviation_mm
    }
  }
  abort("missing through-bore approximation")
}

///|
test "assembly feature aggregation keeps the largest deviation" {
  let m3 = match @fasteners.iso4032_nut(@standards.M3) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let m5 = match @fasteners.iso4032_nut(@standards.M5) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  // Add the larger approximation first, then the smaller one: the old
  // first-wins dedupe kept the smaller value and understated the error.
  let assembly = @assemblies.Assembly::new(name="aggregate")
    .add(m5, instance_name="m5")
    .add(m3, instance_name="m3")
  let mut found = -1.0
  for a in assembly.features().approximated {
    if a.feature == "through-bore" {
      found = a.deviation_mm
    }
  }
  assert_true(found >= through_bore_deviation(m5) - 1.0e-12)
  assert_true(found > through_bore_deviation(m3))
}

///|
test "bolted joint accepts an explicit standard screw length" {
  // M3 nut (2.4) + two 1 mm plates + 0.5 mm washer = 4.9 mm, below the ISO
  // 4762 M3 minimum of 5 mm. The default therefore errors; the caller can
  // choose the standard 5 mm length.
  assert_true(
    @assemblies.bolted_joint(@standards.M3, 40.0, 30.0, 1.0) is Err(_),
  )
  assert_true(
    @assemblies.bolted_joint(
      @standards.M3,
      40.0,
      30.0,
      1.0,
      screw_length_mm=5.0,
    )
    is Ok(_),
  )
  assert_true(
    @assemblies.bolted_joint(
      @standards.M3,
      40.0,
      30.0,
      1.0,
      screw_length_mm=4.0,
    )
    is Err(_),
  )
}
