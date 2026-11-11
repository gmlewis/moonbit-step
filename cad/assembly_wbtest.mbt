///|
fn tree_design() -> Design {
  Design::new(name="tree")
  .add(Cuboid::new(10.0, 10.0, 10.0).with_name("a"))
  .add(Cuboid::new(10.0, 10.0, 10.0).with_name("b").translate(x=20.0))
  .add(Cuboid::new(10.0, 10.0, 10.0).with_name("c").translate(z=20.0))
}

///|
test "assembly emits one parent product and one per node" {
  let step = tree_design().to_assembly_step(assembly_name="tree-asm")
  inspect(step.split("PRODUCT(").count() - 1, content="4")
  inspect(
    step.split("NEXT_ASSEMBLY_USAGE_OCCURRENCE(").count() - 1,
    content="3",
  )
}

///|
test "assembly emits one placement transformation per node" {
  let step = tree_design().to_assembly_step(assembly_name="tree-asm")
  inspect(step.split("ITEM_DEFINED_TRANSFORMATION(").count() - 1, content="3")
  inspect(
    step.split("CONTEXT_DEPENDENT_SHAPE_REPRESENTATION(").count() - 1,
    content="3",
  )
}

///|
test "assembly does not change flat export" {
  let design = tree_design()
  let before = design.to_step_file()
  let _ = design.to_assembly_step(assembly_name="tree-asm")
  let after = design.to_step_file()
  // Compare the DATA section only: the header carries a wall-clock timestamp,
  // so a full-text equality check is flaky when the two exports straddle a
  // second boundary. The DATA section is the geometry that must not change.
  let before_data = before.split("DATA;").collect()
  let after_data = after.split("DATA;").collect()
  assert_eq(before_data.length(), after_data.length())
  assert_eq(before_data[1], after_data[1])
  assert_false(before.contains("NEXT_ASSEMBLY_USAGE_OCCURRENCE("))
}
