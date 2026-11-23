///|
// Explicit trait-method promotion declarations.
//
// MoonBit no longer promotes a trait's methods to direct methods on a type
// implicitly: every promoted method needs an explicit `extend` declaration,
// otherwise moonc warns (implicit_impl_as_method). The primary method of each
// trait is promoted here plainly. The defaulted derivative that the `!=`
// operator or string interpolation already covers (`Eq::not_equal`,
// `Show::output`) is promoted as well - moonc otherwise warns about its
// implicit promotion - but deprecated and hidden, so those two blocks live in
// `deprecated.mbt`.

///|
pub extend LoaderError with Eq::{equal}

///|
pub extend LoaderError with Show::{to_string}

///|
pub extend Rgb with Debug::{to_repr}

///|
pub extend Length with Add::{add}

///|
pub extend Length with Sub::{sub}

///|
pub extend Length with Neg::{neg}
