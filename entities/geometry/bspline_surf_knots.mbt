///|
// Represents a B_SPLINE_SURFACE_WITH_KNOTS entity.
// In STEP Part 21 files this most commonly appears as a part of a complex
// instance together with B_SPLINE_SURFACE and (optionally) RATIONAL_B_SPLINE_SURFACE.
// Example (from MachineContactMedium.step):
//   B_SPLINE_SURFACE_WITH_KNOTS((3,3),(3,2,3),(-0.16,...),(-3.14,...),.UNSPECIFIED.)
//
// Notes:
// - We store knot values as raw strings to preserve STEP formatting.
pub struct BSplineSurfaceWithKnots {
  u_multiplicities : Array[Int]
  v_multiplicities : Array[Int]
  u_knots : Array[String]
  v_knots : Array[String]
  knot_spec : String
}

///|
pub fn BSplineSurfaceWithKnots::new(
  u_multiplicities : Array[Int],
  v_multiplicities : Array[Int],
  u_knots : Array[String],
  v_knots : Array[String],
  knot_spec : String,
) -> BSplineSurfaceWithKnots {
  BSplineSurfaceWithKnots::{
    u_multiplicities,
    v_multiplicities,
    u_knots,
    v_knots,
    knot_spec,
  }
}

///|
pub impl @step.Entity for BSplineSurfaceWithKnots with to_step(self) {
  let u_mults_str = self.u_multiplicities.map(fn(i) { "\{i}" }).join(",")
  let v_mults_str = self.v_multiplicities.map(fn(i) { "\{i}" }).join(",")
  let u_knots_str = self.u_knots.join(",")
  let v_knots_str = self.v_knots.join(",")
  "B_SPLINE_SURFACE_WITH_KNOTS((\{u_mults_str}),(\{v_mults_str}),(\{u_knots_str}),(\{v_knots_str}),\{self.knot_spec})"
}
