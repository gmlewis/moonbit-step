///|
// Represents a FACE_BOUND entity.
// Example from MachineContactMedium.step:
//   FACE_BOUND('',#158,.T.)
pub struct FaceBound {
  name : String
  bound : @step.Ref
  orientation : Bool
}

///|
pub fn FaceBound::new(
  name : String,
  bound : @step.Ref,
  orientation : Bool,
) -> FaceBound {
  FaceBound::{ name, bound, orientation }
}

///|
pub impl @step.Entity for FaceBound with to_step(self) {
  let bound_str = "#\{self.bound.id.value}"
  let ori_str = bool_to_step(self.orientation)
  "FACE_BOUND(\{step_str_or_dollar(self.name)},\{bound_str},\{ori_str})"
}
