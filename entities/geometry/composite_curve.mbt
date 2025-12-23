///|
// Represents a transition_code enumeration in STEP.
pub(all) enum TransitionCode {
  Discontinuous
  Continuous
  ContSameGradient
  ContSameGradientSameCurvature
}

///|
pub impl @step.Entity for TransitionCode with to_step(self) {
  match self {
    Discontinuous => ".DISCONTINUOUS."
    Continuous => ".CONTINUOUS."
    ContSameGradient => ".CONTSAMEGRADIENT."
    ContSameGradientSameCurvature => ".CONTSAMEGRADIENTSAMECURVATURE."
  }
}

///|
pub fn TransitionCode::from_string(s : String) -> TransitionCode? {
  match s {
    ".DISCONTINUOUS." => Some(Discontinuous)
    ".CONTINUOUS." => Some(Continuous)
    ".CONTSAMEGRADIENT." => Some(ContSameGradient)
    ".CONTSAMEGRADIENTSAMECURVATURE." => Some(ContSameGradientSameCurvature)
    _ => None
  }
}

///|
// Represents a COMPOSITE_CURVE_SEGMENT entity.
// Example:
//   COMPOSITE_CURVE_SEGMENT(.CONTINUOUS., .T., #10)
// where #10 is a curve.
pub struct CompositeCurveSegment {
  transition : TransitionCode
  same_sense : Bool
  parent_curve : @step.Ref
}

///|
pub fn CompositeCurveSegment::new(
  transition : TransitionCode,
  same_sense : Bool,
  parent_curve : @step.Ref,
) -> CompositeCurveSegment {
  CompositeCurveSegment::{ transition, same_sense, parent_curve }
}

///|
pub impl @step.Entity for CompositeCurveSegment with to_step(self) {
  let trans_str = @step.Entity::to_step(self.transition)
  let sense_str = bool_to_step(self.same_sense)
  let curve_str = "#\{self.parent_curve.id.value}"
  "COMPOSITE_CURVE_SEGMENT(\{trans_str},\{sense_str},\{curve_str})"
}

///|
// Represents a COMPOSITE_CURVE entity.
// Example:
//   COMPOSITE_CURVE('name', (#10, #20), .F.)
// where #10, #20 are COMPOSITE_CURVE_SEGMENTs.
pub struct CompositeCurve {
  name : String
  segments : Array[@step.Ref]
  self_intersect : Bool
}

///|
pub fn CompositeCurve::new(
  name : String,
  segments : Array[@step.Ref],
  self_intersect : Bool,
) -> CompositeCurve {
  CompositeCurve::{ name, segments, self_intersect }
}

///|
pub impl @step.Entity for CompositeCurve with to_step(self) {
  let segments_str = self.segments.map(fn(r) { "#\{r.id.value}" }).join(",")
  let si_str = bool_to_step(self.self_intersect)
  "COMPOSITE_CURVE(\{@step.step_str(self.name)},(\{segments_str}),\{si_str})"
}
