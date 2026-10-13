///|
// Represents a COORDINATED_UNIVERSAL_TIME_OFFSET entity.
// Example:
//   COORDINATED_UNIVERSAL_TIME_OFFSET(8, 0, .AHEAD.)
pub struct CoordinatedUniversalTimeOffset {
  hour_offset : Int32
  minute_offset : Int32
  sense : String // .AHEAD., .BEHIND., .EXACT.
}

///|
pub fn CoordinatedUniversalTimeOffset::new(
  hour_offset : Int32,
  minute_offset : Int32,
  sense : String,
) -> CoordinatedUniversalTimeOffset {
  CoordinatedUniversalTimeOffset::{ hour_offset, minute_offset, sense, }
}

///|
pub impl @step.Entity for CoordinatedUniversalTimeOffset with fn to_step(self) {
  "COORDINATED_UNIVERSAL_TIME_OFFSET(\{self.hour_offset},\{self.minute_offset},\{self.sense})"
}
