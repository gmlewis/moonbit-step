///|
test "AdvancedFace to_step" {
  let e = AdvancedFace::new(
    "",
    [@step.Ref::{ id: @step.EntityId::{ value: 46 } }],
    @step.Ref::{ id: @step.EntityId::{ value: 40 } },
    false,
  )
  inspect(@step.Entity::to_step(e), content="ADVANCED_FACE('',(#46),#40,.F.)")
}
