///|
test "CoordinatedUniversalTimeOffset::to_step" {
  let c = @product.CoordinatedUniversalTimeOffset::new(8, 0, ".AHEAD.")
  inspect(
    @step.Entity::to_step(c),
    content="COORDINATED_UNIVERSAL_TIME_OFFSET(8,0,.AHEAD.)",
  )
}

///|
test "CalendarDate::to_step" {
  let c = @product.CalendarDate::new(2025, 22, 12)
  inspect(@step.Entity::to_step(c), content="CALENDAR_DATE(2025,22,12)")
}

///|
test "LocalTime::to_step" {
  let zone = @step.Ref::{ id: { value: 10, }, }
  let l = @product.LocalTime::new(12, 30, 0.0, zone)
  inspect(@step.Entity::to_step(l), content="LOCAL_TIME(12,30,0.0,#10)")
}

///|
test "DateAndTime::to_step" {
  let d = @step.Ref::{ id: { value: 10, }, }
  let t = @step.Ref::{ id: { value: 20, }, }
  let dt = @product.DateAndTime::new(d, t)
  inspect(@step.Entity::to_step(dt), content="DATE_AND_TIME(#10,#20)")
}
