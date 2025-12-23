///|
// Represents a PERSON entity.
// Example:
//   PERSON('id', 'last', 'first', ('middle'), ('prefix'), ('suffix'))
pub struct Person {
  id : String
  last_name : String
  first_name : String
  middle_names : Array[String]
  prefix_titles : Array[String]
  suffix_titles : Array[String]
}

///|
pub fn Person::new(
  id : String,
  last_name : String,
  first_name : String,
  middle_names : Array[String],
  prefix_titles : Array[String],
  suffix_titles : Array[String],
) -> Person {
  Person::{
    id,
    last_name,
    first_name,
    middle_names,
    prefix_titles,
    suffix_titles,
  }
}

///|
pub impl @step.Entity for Person with to_step(self) {
  let middles = "(" + self.middle_names.map(@step.step_str).join(",") + ")"
  let prefixes = "(" + self.prefix_titles.map(@step.step_str).join(",") + ")"
  let suffixes = "(" + self.suffix_titles.map(@step.step_str).join(",") + ")"
  "PERSON(\{@step.step_str(self.id)},\{@step.step_str(self.last_name)},\{@step.step_str(self.first_name)},\{middles},\{prefixes},\{suffixes})"
}
