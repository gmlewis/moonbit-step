///|
/// SpecError is the common validation failure type for component
/// specifications.
///
/// Constructors carry a human-readable message so callers can report the exact
/// parameter that was rejected instead of guessing which check failed.
pub(all) enum SpecError {
  InvalidSize(String)
  UnsupportedLength(String)
  InvalidDimension(String)
  InvalidParameter(String)
}

///|
pub fn SpecError::message(self : SpecError) -> String {
  match self {
    InvalidSize(m) => m
    UnsupportedLength(m) => m
    InvalidDimension(m) => m
    InvalidParameter(m) => m
  }
}

///|
pub fn SpecError::to_string(self : SpecError) -> String {
  self.message()
}

///|
/// is_finite rejects NaN and infinities so a component cannot be built from a
/// value that would corrupt the STEP geometry.
pub fn is_finite(v : Double) -> Bool {
  v == v && v.abs() < 1.0e300
}

///|
/// require_positive validates a strictly positive, finite dimension.
pub fn require_positive(name : String, v : Double) -> Result[Unit, SpecError] {
  if !is_finite(v) {
    return Err(InvalidDimension("\{name} must be finite, got \{v}"))
  }
  if v <= 0.0 {
    return Err(InvalidDimension("\{name} must be > 0, got \{v}"))
  }
  Ok(())
}

///|
/// require_non_negative validates a finite dimension that may be zero.
pub fn require_non_negative(
  name : String,
  v : Double,
) -> Result[Unit, SpecError] {
  if !is_finite(v) {
    return Err(InvalidDimension("\{name} must be finite, got \{v}"))
  }
  if v < 0.0 {
    return Err(InvalidDimension("\{name} must be >= 0, got \{v}"))
  }
  Ok(())
}

///|
/// require_in_range validates a finite value inside an inclusive range.
pub fn require_in_range(
  name : String,
  v : Double,
  min : Double,
  max : Double,
) -> Result[Unit, SpecError] {
  if !is_finite(v) {
    return Err(InvalidDimension("\{name} must be finite, got \{v}"))
  }
  if v < min || v > max {
    return Err(
      InvalidParameter("\{name} must be within [\{min}, \{max}] mm, got \{v}"),
    )
  }
  Ok(())
}

///|
/// near compares two lengths with an absolute tolerance in millimetres.
pub fn near(a : Double, b : Double, tol~ : Double = 1.0e-9) -> Bool {
  (a - b).abs() <= tol
}

///|
/// expect_ok unwraps a validated specification, aborting with the validation
/// message when it is invalid. Use this at the top of an executable where a bad
/// command-line value should stop the program.
pub fn[T] expect_ok(r : Result[T, SpecError]) -> T {
  match r {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
}

///|
/// expect_mm converts a Length to millimetres, rejecting non-finite values.
pub fn length_mm(name : String, v : @cad.Length) -> Result[Double, SpecError] {
  let mm = v.to_mm()
  match require_positive(name, mm) {
    Ok(_) => Ok(mm)
    Err(e) => Err(e)
  }
}
