///|
// Represents a BOOLEAN_OPERATOR enumeration in STEP.
pub(all) enum BooleanOperator {
  Union
  Intersection
  Difference
}

///|
pub impl @step.Entity for BooleanOperator with to_step(self) {
  match self {
    Union => ".UNION."
    Intersection => ".INTERSECTION."
    Difference => ".DIFFERENCE."
  }
}

///|
pub fn BooleanOperator::from_string(s : String) -> BooleanOperator? {
  match s {
    ".UNION." => Some(Union)
    ".INTERSECTION." => Some(Intersection)
    ".DIFFERENCE." => Some(Difference)
    _ => None
  }
}

///|
// Represents a BOOLEAN_RESULT entity.
// Example:
//   BOOLEAN_RESULT('name', .UNION., #10, #20)
pub struct BooleanResult {
  name : String
  operator : BooleanOperator
  first_operand : @step.Ref
  second_operand : @step.Ref
}

///|
pub fn BooleanResult::new(
  name : String,
  operator : BooleanOperator,
  first_operand : @step.Ref,
  second_operand : @step.Ref,
) -> BooleanResult {
  BooleanResult::{ name, operator, first_operand, second_operand }
}

///|
pub impl @step.Entity for BooleanResult with to_step(self) {
  let op_str = @step.Entity::to_step(self.operator)
  let op1_str = "#\{self.first_operand.id.value}"
  let op2_str = "#\{self.second_operand.id.value}"
  "BOOLEAN_RESULT(\{@step.step_str(self.name)},\{op_str},\{op1_str},\{op2_str})"
}
