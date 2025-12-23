///|
// Represents a DATE_AND_TIME entity.
// Example:
//   DATE_AND_TIME(#10, #20)
// where #10 is a CALENDAR_DATE and #20 is a LOCAL_TIME.
pub struct DateAndTime {
  date_component : @step.Ref
  time_component : @step.Ref
}

///|
pub fn DateAndTime::new(
  date_component : @step.Ref,
  time_component : @step.Ref,
) -> DateAndTime {
  DateAndTime::{ date_component, time_component }
}

///|
pub impl @step.Entity for DateAndTime with to_step(self) {
  let date_str = "#\{self.date_component.id.value}"
  let time_str = "#\{self.time_component.id.value}"
  "DATE_AND_TIME(\{date_str},\{time_str})"
}
