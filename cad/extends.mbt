///|
// Explicit trait-method promotion declarations.
//
// MoonBit no longer promotes a trait's methods to direct methods on a type
// implicitly: every promoted method needs an explicit `extend` declaration,
// otherwise moonc warns (implicit_impl_as_method). The primary method of each
// trait is promoted here plainly. The defaulted derivative that the `!=`
// operator or string interpolation already covers (`Eq::not_equal`,
// `Show::output`) is promoted as well - moonc otherwise warns about its
// implicit promotion - but deprecated and hidden, since there is no reason to
// call it directly.

///|
pub extend LoaderError with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend LoaderError with Eq::{not_equal}

///|
pub extend LoaderError with Show::{to_string}

///|
#deprecated("Use `Show::output` via the trait or `to_string` instead", skip_current_package=true)
#doc(hidden)
pub extend LoaderError with Show::{output}

///|
pub extend Rgb with Debug::{to_repr}
