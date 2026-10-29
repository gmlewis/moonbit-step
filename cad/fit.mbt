///|
/// Fit captures the intended clearance of a printed hole as intent rather than
/// as a literal the caller has to compute.
///
/// Clearance is per face, so a hole's diameter grows by `2 * per_face_mm`.
/// Only voids grow: material additions (bosses, pins) are out of scope. These
/// values are a starting point for FDM printing, not a universal standard; an
/// explicit number is still allowed wherever a `Double` is expected.
///
/// STEP export stays nominal: `fit` changes the modelled void, not a printer
/// compensation layer, so do not treat it as printer calibration.
pub(all) enum Fit {
  /// 0.00 mm per face.
  Nominal
  /// 0.10 mm per face.
  Close
  /// 0.25 mm per face.
  Free
  /// -0.05 mm per face (interference).
  Press
}

///|
/// Fit::per_face_mm returns the radial clearance implied by the fit.
pub fn Fit::per_face_mm(self : Fit) -> Double {
  match self {
    Nominal => 0.0
    Close => 0.10
    Free => 0.25
    Press => -0.05
  }
}

///|
/// Profile2D::circle_with_fit returns a counter-clockwise circle whose diameter
/// is grown by `2 * fit.per_face_mm()` (so the radius grows by the per-face
/// clearance). Voids grow; it never adds material.
pub fn Profile2D::circle_with_fit(
  diameter : Double,
  fit~ : Fit,
  segments~ : Int32 = 64,
) -> Array[Vec2] {
  Profile2D::circle(diameter + 2.0 * fit.per_face_mm(), segments~)
}

///|
/// Profile2D::hole_with_fit returns a clockwise (hole) loop with the same
/// clearance semantics as `Profile2D::circle_with_fit`.
pub fn Profile2D::hole_with_fit(
  diameter : Double,
  fit~ : Fit,
  segments~ : Int32 = 64,
) -> Array[Vec2] {
  Profile2D::circle_with_fit(diameter, fit~, segments~).rev()
}
