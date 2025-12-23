///|
// Represents a CALENDAR_DATE entity.
// Example:
//   CALENDAR_DATE(2025, 22, 12)
pub struct CalendarDate {
  year_component : Int
  day_component : Int
  month_component : Int
}

///|
pub fn CalendarDate::new(
  year_component : Int,
  day_component : Int,
  month_component : Int,
) -> CalendarDate {
  CalendarDate::{ year_component, day_component, month_component }
}

///|
pub impl @step.Entity for CalendarDate with to_step(self) {
  "CALENDAR_DATE(\{self.year_component},\{self.day_component},\{self.month_component})"
}
