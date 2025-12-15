///|
test "direction_to_step" {
  let d = Direction::new("DIR1", [0.0, 0.0, 1.0])
  inspect(@step.Entity::to_step(d), content="DIRECTION('DIR1',(0.0,0.0,1.0))")
}
