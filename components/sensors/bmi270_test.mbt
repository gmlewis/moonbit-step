///|
test "SparkFun BMI270 Qwiic 1x1 layout and mate connectors match official .brd" {
  let p = @sensors.Bmi270Params::qwiic_1x1().unwrap()
  let layout = @sensors.bmi270_layout(p)
  assert_true((layout.width_mm - 25.4).abs() < 1.0e-9)
  assert_true((layout.height_mm - 25.4).abs() < 1.0e-9)
  assert_eq(layout.mounting_holes_xy.length(), 4)
  assert_true(layout.imu_center_xy.0.abs() < 1.0e-9)
  assert_true(layout.imu_center_xy.1.abs() < 1.0e-9)

  let comp = @sensors.sparkfun_bmi270(p).unwrap()
  // PCB + BMI270 IC + 2 Qwiic connectors = 4 layers
  assert_eq(comp.layers().length(), 4)
  assert_true(comp.connector("mount-bottom") is Ok(_))
  assert_true(comp.connector("mount-top") is Ok(_))
  assert_true(comp.connector("imu-origin") is Ok(_))
  assert_true(comp.connector("hole-1") is Ok(_))
  assert_true(comp.connector("hole-4") is Ok(_))
  assert_true(comp.connector("qwiic-right") is Ok(_))
  assert_true(comp.connector("qwiic-left") is Ok(_))

  let step = comp.to_design().to_step_file()
  assert_true(step.contains("ISO-10303-21;"))
  assert_true(step.contains("CLOSED_SHELL("))
}

///|
test "SparkFun BMI270 Qwiic Micro layout and mate connectors match official .brd" {
  let p = @sensors.Bmi270Params::qwiic_micro().unwrap()
  let layout = @sensors.bmi270_layout(p)
  assert_true((layout.width_mm - 7.62).abs() < 1.0e-9)
  assert_true((layout.height_mm - 19.05).abs() < 1.0e-9)
  assert_eq(layout.mounting_holes_xy.length(), 1)

  let comp = @sensors.sparkfun_bmi270(p).unwrap()
  // PCB + BMI270 IC + 1 Qwiic connector = 3 layers
  assert_eq(comp.layers().length(), 3)
  assert_true(comp.connector("hole-1") is Ok(_))
  assert_true(comp.connector("qwiic-south") is Ok(_))
  assert_true(comp.connector("imu-origin") is Ok(_))
}
