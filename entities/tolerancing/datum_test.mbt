///|
test "Datum::to_step" {
  let shape = @step.Ref::{ id: { value: 10 } }
  let d = Datum::new("name", "desc", shape, ".T.", "A")
  inspect(@step.Entity::to_step(d), content="DATUM('name','desc',#10,.T.,'A')")
}

///|
test "DatumFeature::to_step" {
  let shape = @step.Ref::{ id: { value: 10 } }
  let df = DatumFeature::new("name", "desc", shape, ".T.")
  inspect(
    @step.Entity::to_step(df),
    content="DATUM_FEATURE('name','desc',#10,.T.)",
  )
}
