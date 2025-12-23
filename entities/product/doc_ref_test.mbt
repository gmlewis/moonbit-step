///|
test "DocumentReference::to_step" {
  let doc = @step.Ref::{ id: { value: 10 } }
  let dr = DocumentReference::new("id", "name", "desc", doc)
  let s = @step.Entity::to_step(dr)
  inspect(s, content="DOCUMENT_REFERENCE('id','name','desc',#10)")
}
