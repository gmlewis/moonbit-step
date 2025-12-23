///|
// Represents a COORDINATED_UNIVERSAL_TIME_OFFSET entity.
// Example:
//   COORDINATED_UNIVERSAL_TIME_OFFSET(8, 0, .AHEAD.)
pub struct CoordinatedUniversalTimeOffset {
  hour_offset : Int
  minute_offset : Int
  sense : String // .AHEAD., .BEHIND., .EXACT.
}

///|
pub fn CoordinatedUniversalTimeOffset::new(
  hour_offset : Int,
  minute_offset : Int,
  sense : String,
) -> CoordinatedUniversalTimeOffset {
  CoordinatedUniversalTimeOffset::{ hour_offset, minute_offset, sense }
}

///|
pub impl @step.Entity for CoordinatedUniversalTimeOffset with to_step(self) {
  "COORDINATED_UNIVERSAL_TIME_OFFSET(\{self.hour_offset},\{self.minute_offset},\{self.sense})"
}
