///|
// Represents a LOCAL_TIME entity.
// Example:
//   LOCAL_TIME(12, 30, 0.0, #10)
// where #10 is a COORDINATED_UNIVERSAL_TIME_OFFSET.
pub struct LocalTime {
  hour_component : Int
  minute_component : Int
  second_component : Double
  zone : @step.Ref
}

///|
pub fn LocalTime::new(
  hour_component : Int,
  minute_component : Int,
  second_component : Double,
  zone : @step.Ref,
) -> LocalTime {
  LocalTime::{ hour_component, minute_component, second_component, zone }
}

///|
pub impl @step.Entity for LocalTime with to_step(self) {
  let zone_str = "#\{self.zone.id.value}"
  "LOCAL_TIME(\{self.hour_component},\{self.minute_component},\{@step.fmt_num(self.second_component)},\{zone_str})"
}
