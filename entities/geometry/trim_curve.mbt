///|
// Represents a TRIMMED_CURVE entity.
//
// Common form:
//   TRIMMED_CURVE('',#<basis>,(PARAMETER_VALUE(0.)),(PARAMETER_VALUE(1.)),.T.,.PARAMETER.)
pub struct TrimmedCurve {
  name : String
  basis_curve : @step.Ref
  trim_1 : String
  trim_2 : String
  sense_agreement : Bool
  master_representation : String
}

///|
pub fn TrimmedCurve::new(
  name : String,
  basis_curve : @step.Ref,
  trim_1 : String,
  trim_2 : String,
  sense_agreement : Bool,
  master_representation : String,
) -> TrimmedCurve {
  TrimmedCurve::{
    name,
    basis_curve,
    trim_1,
    trim_2,
    sense_agreement,
    master_representation,
  }
}

///|
pub impl @step.Entity for TrimmedCurve with to_step(self) {
  let basis_str = "#\{self.basis_curve.id.value}"
  let sense_str = bool_to_step(self.sense_agreement)
  "TRIMMED_CURVE(\{step_str_or_dollar(self.name)},\{basis_str},\{self.trim_1},\{self.trim_2},\{sense_str},\{self.master_representation})"
}
