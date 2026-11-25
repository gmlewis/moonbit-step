///|
/// 03-bmi270-imu
///
/// SparkFun 6DoF IMU Breakout — BMI270 (Qwiic) (`SEN-22397` 1"x1" and
/// `SEN-22398` Qwiic Micro) with exact analytic mounting holes, Qwiic JST-SH
/// connectors, BMI270 LGA-14 package, and contact-plane mate connectors.

///|
async fn main {
  let spec = {
    "variant": @cli.opt_string(
      help="Board variant: '1x1' (SEN-22397, 25.4x25.4 mm, default) or 'micro' (SEN-22398, 7.62x19.05 mm)",
    ),
    "out": @cli.opt_string(
      help="Output STEP file path (default: stdout)",
      short='o',
    ),
    "scScript": @cli.opt_string(
      help="Write a native SolidCraft JSON command script for live GUI streaming",
    ),
  }
  guard @cli.parse(
      spec,
      prog="03-bmi270-imu",
      description="SparkFun 6DoF IMU Breakout - BMI270 (Qwiic) mechanical model.",
    )
    is Some(args) else {
    return
  }

  let variant = args.string_opt("variant").unwrap_or("1x1")
  let params_res = if variant == "micro" {
    @sensors.Bmi270Params::qwiic_micro()
  } else {
    @sensors.Bmi270Params::qwiic_1x1()
  }
  let params = match params_res {
    Ok(p) => p
    Err(e) => {
      @cli.eprintln("error: " + e.to_string())
      abort("")
    }
  }
  let comp = match @sensors.sparkfun_bmi270(params) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.to_string())
      abort("")
    }
  }

  match args.string_opt("scScript") {
    Some(sc_path) => {
      comp.to_design().write_solidcraft_script(sc_path)
      println("Wrote SolidCraft script: " + sc_path)
      return
    }
    None => ()
  }

  comp.write_step(args.string_opt("out"))
}
