///|
test "SecurityClassificationLevel::to_step" {
  let level = SecurityClassificationLevel::new("unclassified")
  let s = @step.Entity::to_step(level)
  inspect(s, content="SECURITY_CLASSIFICATION_LEVEL('unclassified')")
}

///|
test "SecurityClassification::to_step" {
  let level = @step.Ref::{ id: { value: 10 } }
  let sc = SecurityClassification::new("name", "purpose", level)
  let s = @step.Entity::to_step(sc)
  inspect(s, content="SECURITY_CLASSIFICATION('name','purpose',#10)")
}
