///|
// Represents a RATIONAL_B_SPLINE_SURFACE entity.
// Common form (as part of a complex surface instance):
//   RATIONAL_B_SPLINE_SURFACE(((1.,0.7,1.),( ... ),( ... )))
//
// Notes:
// - We store weights as raw strings to preserve STEP formatting.
pub struct RationalBSplineSurface {
  weights : Array[Array[String]]
}

///|
pub fn RationalBSplineSurface::new(
  weights : Array[Array[String]],
) -> RationalBSplineSurface {
  RationalBSplineSurface::{ weights, }
}

///|
pub impl @step.Entity for RationalBSplineSurface with to_step(self) {
  let row_strs = self.weights
    .map(fn(row) {
      let r = row.join(",")
      "(\{r})"
    })
    .join(",")
  "RATIONAL_B_SPLINE_SURFACE((\{row_strs}))"
}
