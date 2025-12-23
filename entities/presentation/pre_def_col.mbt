///|
// Represents a DRAUGHTING_PRE_DEFINED_COLOUR entity.
// Example:
//   DRAUGHTING_PRE_DEFINED_COLOUR('red')
pub struct DraughtingPreDefinedColour {
  name : String
}

///|
pub fn DraughtingPreDefinedColour::new(
  name : String,
) -> DraughtingPreDefinedColour {
  DraughtingPreDefinedColour::{ name, }
}

///|
pub impl @step.Entity for DraughtingPreDefinedColour with to_step(self) {
  "DRAUGHTING_PRE_DEFINED_COLOUR(\{@step.step_str(self.name)})"
}
