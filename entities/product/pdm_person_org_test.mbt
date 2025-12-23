///|
test "Person::to_step" {
  let p = Person::new("p1", "Doe", "John", ["M"], ["Mr"], ["Jr"])
  let s = @step.Entity::to_step(p)
  inspect(s, content="PERSON('p1','Doe','John',('M'),('Mr'),('Jr'))")
}

///|
test "Organization::to_step" {
  let o = Organization::new("o1", "ACME", "Acme Corp")
  let s = @step.Entity::to_step(o)
  inspect(s, content="ORGANIZATION('o1','ACME','Acme Corp')")
}

///|
test "PersonAndOrganization::to_step" {
  let p = @step.Ref::{ id: { value: 10 } }
  let o = @step.Ref::{ id: { value: 20 } }
  let po = PersonAndOrganization::new(p, o)
  let s = @step.Entity::to_step(po)
  inspect(s, content="PERSON_AND_ORGANIZATION(#10,#20)")
}

///|
test "ApprovalRole::to_step" {
  let ar = ApprovalRole::new("approver")
  let s = @step.Entity::to_step(ar)
  inspect(s, content="APPROVAL_ROLE('approver')")
}

///|
test "ApprovalPersonOrganization::to_step" {
  let po = @step.Ref::{ id: { value: 10 } }
  let a = @step.Ref::{ id: { value: 20 } }
  let r = @step.Ref::{ id: { value: 30 } }
  let apo = ApprovalPersonOrganization::new(po, a, r)
  let s = @step.Entity::to_step(apo)
  inspect(s, content="APPROVAL_PERSON_ORGANIZATION(#10,#20,#30)")
}
