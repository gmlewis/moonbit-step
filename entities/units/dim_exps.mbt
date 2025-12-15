///|
// Represents a DIMENSIONAL_EXPONENTS entity.
pub struct DimensionalExponents {
  length_exponent : Double
  mass_exponent : Double
  time_exponent : Double
  electric_current_exponent : Double
  thermodynamic_temperature_exponent : Double
  amount_of_substance_exponent : Double
  luminous_intensity_exponent : Double
}

///|
pub fn DimensionalExponents::new(
  length_exponent : Double,
  mass_exponent : Double,
  time_exponent : Double,
  electric_current_exponent : Double,
  thermodynamic_temperature_exponent : Double,
  amount_of_substance_exponent : Double,
  luminous_intensity_exponent : Double,
) -> DimensionalExponents {
  DimensionalExponents::{
    length_exponent,
    mass_exponent,
    time_exponent,
    electric_current_exponent,
    thermodynamic_temperature_exponent,
    amount_of_substance_exponent,
    luminous_intensity_exponent,
  }
}

///|
pub impl @step.Entity for DimensionalExponents with to_step(self) {
  let l = @step.fmt_num(self.length_exponent)
  let m = @step.fmt_num(self.mass_exponent)
  let t = @step.fmt_num(self.time_exponent)
  let i = @step.fmt_num(self.electric_current_exponent)
  let th = @step.fmt_num(self.thermodynamic_temperature_exponent)
  let n = @step.fmt_num(self.amount_of_substance_exponent)
  let j = @step.fmt_num(self.luminous_intensity_exponent)
  "DIMENSIONAL_EXPONENTS(\{l},\{m},\{t},\{i},\{th},\{n},\{j})"
}
