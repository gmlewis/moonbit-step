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
  assert_eq(before, after)
  assert_false(before.contains("NEXT_ASSEMBLY_USAGE_OCCURRENCE("))
}
