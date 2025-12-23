///|
test "DocumentType::to_step" {
  let dt = DocumentType::new("standard")
  let s = @step.Entity::to_step(dt)
  inspect(s, content="DOCUMENT_TYPE('standard')")
}

///|
test "Document::to_step" {
  let kind = @step.Ref::{ id: { value: 10 } }
  let d = Document::new("d1", "name", "desc", kind)
  let s = @step.Entity::to_step(d)
  inspect(s, content="DOCUMENT('d1','name','desc',#10)")
}
