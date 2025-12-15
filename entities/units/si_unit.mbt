///|
// Represents a SI_UNIT entity (often used inside complex instances).
// Examples:
//   SI_UNIT($,.RADIAN.)
//   SI_UNIT(.MILLI.,.METRE.)
pub struct SiUnit {
  prefix : String
  name : String
}

///|
pub fn SiUnit::new(prefix : String, name : String) -> SiUnit {
  SiUnit::{ prefix, name }
}

///|
pub impl @step.Entity for SiUnit with to_step(self) {
  "SI_UNIT(\{self.prefix},\{self.name})"
}
