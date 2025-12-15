///|
// Represents a B_SPLINE_CURVE_WITH_KNOTS entity.
// Example from MachineContactMedium.step:
//   B_SPLINE_CURVE_WITH_KNOTS('',3,(#875,#876,...),.UNSPECIFIED.,.F.,.F.,(4,3,...),(0.,...),.UNSPECIFIED.)
//
// Notes:
// - We store knot values as raw strings to preserve STEP formatting.
// - Control points are currently typed as UnknownEntity refs.
pub struct BSplineCurveWithKnots {
  name : String
  degree : Int
  control_points : Array[@step.Ref]
  curve_form : String
  closed_curve : Bool
  self_intersect : Bool
  knot_multiplicities : Array[Int]
  knots : Array[String]
  knot_spec : String
}

///|
pub fn BSplineCurveWithKnots::new(
  name : String,
  degree : Int,
  control_points : Array[@step.Ref],
  curve_form : String,
  closed_curve : Bool,
  self_intersect : Bool,
  knot_multiplicities : Array[Int],
  knots : Array[String],
  knot_spec : String,
) -> BSplineCurveWithKnots {
  BSplineCurveWithKnots::{
    name,
    degree,
    control_points,
    curve_form,
    closed_curve,
    self_intersect,
    knot_multiplicities,
    knots,
    knot_spec,
  }
}

///|
pub impl @step.Entity for BSplineCurveWithKnots with to_step(self) {
  let cps_str = self.control_points.map(fn(r) { "#\{r.id.value}" }).join(",")
  let mults_str = self.knot_multiplicities.map(fn(i) { "\{i}" }).join(",")
  let knots_str = self.knots.join(",")
  let closed_str = bool_to_step(self.closed_curve)
  let si_str = bool_to_step(self.self_intersect)
  "B_SPLINE_CURVE_WITH_KNOTS(\{step_str_or_dollar(self.name)},\{self.degree},(\{cps_str}),\{self.curve_form},\{closed_str},\{si_str},(\{mults_str}),(\{knots_str}),\{self.knot_spec})"
}
