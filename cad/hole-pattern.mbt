///|
/// A mechanical hole pattern shared by mate connectors and `Sketch2D`.
///
/// The pattern records the intended interface (a bolt circle, a bearing seat,
/// or one bore) so a mating plate can punch the holes without duplicating
/// coordinates. Dimensions are millimetres and degrees.
#derive(Debug, Eq)
pub(all) enum HolePattern {
  /// `count` holes on a bolt circle of diameter `bcd_mm`, plus an optional
  /// central pilot bore of `pilot_diam_mm` when it is greater than zero.
  BoltCircle(Int32, Double, Double, Double, Double)
  /// A bearing seat: the plate hole matches `outer_diam_mm`; `bore_diam_mm`
  /// records the shaft bore for downstream checks.
  BearingSeat(Double, Double)
  /// One centered bore.
  SingleBore(Double)
}

///|
pub fn HolePattern::bolt_circle(
  count~ : Int32,
  bcd_mm~ : Double,
  hole_diam_mm~ : Double,
  pilot_diam_mm~ : Double = 0.0,
  start_deg~ : Double = 0.0,
) -> HolePattern {
  BoltCircle(count, bcd_mm, hole_diam_mm, pilot_diam_mm, start_deg)
}

///|
pub fn HolePattern::bearing_seat(
  outer_diam_mm~ : Double,
  bore_diam_mm~ : Double,
) -> HolePattern {
  BearingSeat(outer_diam_mm, bore_diam_mm)
}

///|
pub fn HolePattern::single_bore(diam_mm~ : Double) -> HolePattern {
  SingleBore(diam_mm)
}

///|
fn hp_finite(value : Double) -> Bool {
  value == value && value.abs() != 1.0 / 0.0
}

///|
/// HolePattern::validate checks the dimensions used to punch the pattern.
pub fn HolePattern::validate(self : HolePattern) -> Result[Unit, String] {
  match self {
    BoltCircle(count, bcd, hole_diam, pilot_diam, start_deg) => {
      if count < 0 {
        return Err("bolt circle count must be non-negative")
      }
      if count > 0 && (!hp_finite(bcd) || bcd <= 0.0) {
        return Err("bolt circle diameter must be positive")
      }
      if count > 0 && (!hp_finite(hole_diam) || hole_diam <= 0.0) {
        return Err("bolt hole diameter must be positive")
      }
      if pilot_diam < 0.0 || !hp_finite(pilot_diam) {
        return Err("pilot diameter must be non-negative")
      }
      if !hp_finite(start_deg) {
        return Err("bolt circle start angle must be finite")
      }
      Ok(())
    }
    BearingSeat(outer_diam, bore_diam) => {
      if !hp_finite(outer_diam) || outer_diam <= 0.0 {
        return Err("bearing seat outer diameter must be positive")
      }
      if bore_diam < 0.0 || !hp_finite(bore_diam) {
        return Err("bearing bore diameter must be non-negative")
      }
      if bore_diam >= outer_diam {
        return Err("bearing bore must be smaller than the seat diameter")
      }
      Ok(())
    }
    SingleBore(diam) =>
      if !hp_finite(diam) || diam <= 0.0 {
        Err("bore diameter must be positive")
      } else {
        Ok(())
      }
  }
}

///|
/// HolePattern::describe returns a stable, human-readable summary.
pub fn HolePattern::describe(self : HolePattern) -> String {
  match self {
    BoltCircle(count, bcd, hole_diam, pilot_diam, start_deg) =>
      "bolt-circle " +
      count.to_string() +
      " x " +
      fmt_double(hole_diam, Some(0.001)) +
      " mm on " +
      fmt_double(bcd, Some(0.001)) +
      " mm BCD from " +
      fmt_double(start_deg, Some(0.001)) +
      " deg, pilot " +
      fmt_double(pilot_diam, Some(0.001)) +
      " mm"
    BearingSeat(outer_diam, bore_diam) =>
      "bearing seat " +
      fmt_double(outer_diam, Some(0.001)) +
      " mm / bore " +
      fmt_double(bore_diam, Some(0.001)) +
      " mm"
    SingleBore(diam) => "bore " + fmt_double(diam, Some(0.001)) + " mm"
  }
}
