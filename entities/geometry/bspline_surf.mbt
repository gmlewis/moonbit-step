///|
// Represents a B_SPLINE_SURFACE entity.
// Common form (as part of a complex surface instance):
//   B_SPLINE_SURFACE(2,2,((#1,#2,#3),(#4,#5,#6)),.UNSPECIFIED.,.F.,.F.,.F.)
//
// Notes:
// - Control points are stored as UnknownEntity refs.
pub struct BSplineSurface {
  u_degree : Int
  v_degree : Int
  control_points_list : Array[Array[@step.Ref]]
  surface_form : String
  u_closed : Bool
  v_closed : Bool
  self_intersect : Bool
}

///|
pub fn BSplineSurface::new(
  u_degree : Int,
  v_degree : Int,
  control_points_list : Array[Array[@step.Ref]],
  surface_form : String,
  u_closed : Bool,
  v_closed : Bool,
  self_intersect : Bool,
) -> BSplineSurface {
  BSplineSurface::{
    u_degree,
    v_degree,
    control_points_list,
    surface_form,
    u_closed,
    v_closed,
    self_intersect,
  }
}

///|
pub impl @step.Entity for BSplineSurface with to_step(self) {
  let row_strs = self.control_points_list
    .map(fn(row) {
      let cps_str = row.map(fn(r) { "#\{r.id.value}" }).join(",")
      "(\{cps_str})"
    })
    .join(",")
  let u_closed_str = bool_to_step(self.u_closed)
  let v_closed_str = bool_to_step(self.v_closed)
  let si_str = bool_to_step(self.self_intersect)
  "B_SPLINE_SURFACE(\{self.u_degree},\{self.v_degree},(\{row_strs}),\{self.surface_form},\{u_closed_str},\{v_closed_str},\{si_str})"
}
