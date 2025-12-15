///|
test "ManifoldSolidBrep to_step" {
  let e = ManifoldSolidBrep::new("", @step.Ref::{
    id: @step.EntityId::{ value: 33 },
  })
  inspect(@step.Entity::to_step(e), content="MANIFOLD_SOLID_BREP('',#33)")
}
