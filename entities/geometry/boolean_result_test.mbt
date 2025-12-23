///|
test "BooleanResult::to_step" {
  let op1 = @step.Ref::{ id: { value: 10 } }
  let op2 = @step.Ref::{ id: { value: 20 } }
  let br = BooleanResult::new("test", Union, op1, op2)
  let s = @step.Entity::to_step(br)
  inspect(s, content="BOOLEAN_RESULT('test',.UNION.,#10,#20)")
}

///|
test "BooleanOperator::to_step" {
  inspect(@step.Entity::to_step(BooleanOperator::Union), content=".UNION.")
  inspect(
    @step.Entity::to_step(BooleanOperator::Intersection),
    content=".INTERSECTION.",
  )
  inspect(
    @step.Entity::to_step(BooleanOperator::Difference),
    content=".DIFFERENCE.",
  )
}
