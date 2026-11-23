///|
// Deprecated trait-method promotions.
//
// These are hidden from the public API but must exist so moonc does not warn
// about implicit method promotion (implicit_impl_as_method). Per the project
// convention, deprecated blocks live in `deprecated.mbt`.

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend LoaderError with Eq::{not_equal}

///|
#deprecated("Use `Show::output` via the trait or `to_string` instead", skip_current_package=true)
#doc(hidden)
pub extend LoaderError with Show::{output}
