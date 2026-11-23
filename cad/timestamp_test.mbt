///|
// A timestamp set on the Design intent must be honoured by every STEP emitter,
// not only the flat writer. Without it the FILE_NAME header carries the wall
// clock and two exports can differ if they straddle a second boundary.

fn ts_design() -> @cad.Design {
  @cad.Design::new(name="ts")
  .add(@cad.Cuboid::new(10.0, 10.0, 10.0).with_name("block"))
  .with_timestamp("2025-01-01T00:00:00")
}

///|
test "flat export is byte-identical with a fixed timestamp" {
  let a = ts_design().to_step_file()
  let b = ts_design().to_step_file()
  assert_eq(a, b)
  assert_true(a.contains("2025-01-01T00:00:00"))
}

///|
test "checked export inherits the fixed timestamp" {
  assert_eq(ts_design().to_step_file_checked(), ts_design().to_step_file())
  assert_true(
    ts_design().to_step_file_checked().contains("2025-01-01T00:00:00"),
  )
}

///|
test "assembly export is byte-identical with a fixed timestamp" {
  let a = ts_design().to_assembly_step(assembly_name="asm")
  let b = ts_design().to_assembly_step(assembly_name="asm")
  assert_eq(a, b)
  assert_true(a.contains("2025-01-01T00:00:00"))
}

///|
test "instanced assembly export is byte-identical with a fixed timestamp" {
  let a = ts_design().to_instanced_step_string(assembly_name="asm")
  let b = ts_design().to_instanced_step_string(assembly_name="asm")
  assert_eq(a, b)
  assert_true(a.contains("2025-01-01T00:00:00"))
}

///|
test "csg export is byte-identical with a fixed timestamp" {
  let a = ts_design().to_csg_step()
  let b = ts_design().to_csg_step()
  assert_eq(a, b)
  assert_true(a.contains("2025-01-01T00:00:00"))
}

///|
test "explicit timestamp argument still overrides the design timestamp" {
  let d = ts_design()
  assert_true(d.to_step_file().contains("2025-01-01T00:00:00"))
  assert_true(
    d
    .to_step_file(timestamp="1999-12-31T23:59:59")
    .contains("1999-12-31T23:59:59"),
  )
}
