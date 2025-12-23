///|
test "CertificationType::to_step" {
  let ct = CertificationType::new("standard")
  let s = @step.Entity::to_step(ct)
  inspect(s, content="CERTIFICATION_TYPE('standard')")
}

///|
test "Certification::to_step" {
  let kind = @step.Ref::{ id: { value: 10 } }
  let c = Certification::new("name", "purpose", kind)
  let s = @step.Entity::to_step(c)
  inspect(s, content="CERTIFICATION('name','purpose',#10)")
}
