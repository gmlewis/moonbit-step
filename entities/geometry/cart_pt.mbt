///|
// Represents a CARTESIAN_POINT entity.
// Note the direct mapping of properties from the TS class.
pub struct CartesianPoint {
  name : String
  coordinates : Array[Double]
}

///|
pub fn CartesianPoint::new(
  name : String,
  coordinates : Array[Double],
) -> CartesianPoint {
  CartesianPoint::{ name, coordinates }
}

///|
// Implement the core trait.
pub impl @step.Entity for CartesianPoint with to_step(self) {
  let coords_str = self.coordinates.map(@step.fmt_num).join(",")
  "CARTESIAN_POINT(\{@step.step_str(self.name)},(\{coords_str}))"
}
