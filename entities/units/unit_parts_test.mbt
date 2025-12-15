///|
test "NamedUnit to_step" {
  let u = NamedUnit::new("*")
  inspect(@step.Entity::to_step(u), content="NAMED_UNIT(*)")
}

///|
test "SiUnit to_step" {
  let u = SiUnit::new("$", ".RADIAN.")
  inspect(@step.Entity::to_step(u), content="SI_UNIT($,.RADIAN.)")
}

///|
test "LengthUnit to_step" {
  let u = LengthUnit::new()
  inspect(@step.Entity::to_step(u), content="LENGTH_UNIT()")
}

///|
test "PlaneAngleUnit to_step" {
  let u = PlaneAngleUnit::new()
  inspect(@step.Entity::to_step(u), content="PLANE_ANGLE_UNIT()")
}

///|
test "SolidAngleUnit to_step" {
  let u = SolidAngleUnit::new()
  inspect(@step.Entity::to_step(u), content="SOLID_ANGLE_UNIT()")
}

///|
test "MassUnit to_step" {
  let u = MassUnit::new()
  inspect(@step.Entity::to_step(u), content="MASS_UNIT()")
}

///|
test "ConversionBasedUnit to_step" {
  let u = ConversionBasedUnit::new("DEGREE", @step.Ref::{
    id: @step.EntityId::{ value: 192 },
  })
  inspect(
    @step.Entity::to_step(u),
    content="CONVERSION_BASED_UNIT('DEGREE',#192)",
  )
}
