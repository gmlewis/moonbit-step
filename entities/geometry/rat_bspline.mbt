///|
// Represents a RATIONAL_B_SPLINE_CURVE entity.
// Common form (as part of a complex curve instance):
//   RATIONAL_B_SPLINE_CURVE((1.,1.,1.,1.))
//
// Notes:
// - We store weights as raw strings to preserve STEP formatting.
pub struct RationalBSplineCurve {
  weights : Array[String]
}

///|
pub fn RationalBSplineCurve::new(
  weights : Array[String],
) -> RationalBSplineCurve {
  RationalBSplineCurve::{ weights, }
}

///|
pub impl @step.Entity for RationalBSplineCurve with to_step(self) {
  let weights_str = self.weights.join(",")
  "RATIONAL_B_SPLINE_CURVE((\{weights_str}))"
}
