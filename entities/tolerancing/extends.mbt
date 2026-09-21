///|
// Explicit trait-method promotion declarations.
//
// MoonBit no longer promotes a trait's methods to direct methods on a type
// implicitly: every promoted method needs an explicit `extend` declaration,
// otherwise moonc warns (implicit_impl_as_method). `Entity::to_step` is this
// package's public API, so it is promoted plainly.

///|
pub extend Datum with @step.Entity::{to_step}

///|
pub extend DatumFeature with @step.Entity::{to_step}

///|
pub extend DimensionalSize with @step.Entity::{to_step}

///|
pub extend GeometricTolerance with @step.Entity::{to_step}
