///|
// Represents a FACE_OUTER_BOUND entity.
// Example from simple-box.step:
//   FACE_OUTER_BOUND('',#52,.T.)
pub struct FaceOuterBound {
  name : String
  bound : @step.Ref
  orientation : Bool
}

///|
pub fn FaceOuterBound::new(
  name : String,
  bound : @step.Ref,
  orientation : Bool,
) -> FaceOuterBound {
  FaceOuterBound::{ name, bound, orientation }
}

///|
pub impl @step.Entity for FaceOuterBound with to_step(self) {
  let bound_str = "#\{self.bound.id.value}"
  let ori_str = bool_to_step(self.orientation)
  "FACE_OUTER_BOUND(\{step_str_or_dollar(self.name)},\{bound_str},\{ori_str})"
}
