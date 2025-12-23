///|
// Represents a B_SPLINE_CURVE entity.
// Example:
//   B_SPLINE_CURVE('name', 3, (#10, #11, #12, #13), .UNSPECIFIED., .F., .F.)
pub struct BSplineCurve {
  name : String
  degree : Int
  control_points : Array[@step.Ref]
  curve_form : String
  closed_curve : Bool
  self_intersect : Bool
}

///|
pub fn BSplineCurve::new(
  name : String,
  degree : Int,
  control_points : Array[@step.Ref],
  curve_form : String,
  closed_curve : Bool,
  self_intersect : Bool,
) -> BSplineCurve {
  BSplineCurve::{
    name,
    degree,
    control_points,
    curve_form,
    closed_curve,
    self_intersect,
  }
}

///|
pub impl @step.Entity for BSplineCurve with to_step(self) {
  let cps_str = self.control_points.map(fn(r) { "#\{r.id.value}" }).join(",")
  let closed_str = bool_to_step(self.closed_curve)
  let si_str = bool_to_step(self.self_intersect)
  "B_SPLINE_CURVE(\{step_str_or_dollar(self.name)},\{self.degree},(\{cps_str}),\{self.curve_form},\{closed_str},\{si_str})"
}
