///|
// Explicit trait-method promotion declarations.
//
// MoonBit no longer promotes a trait's methods to direct methods on a type
// implicitly: every promoted method needs an explicit `extend` declaration,
// otherwise moonc warns (implicit_impl_as_method). `Entity::to_step` is this
// package's public API, so it is promoted plainly.

///|
pub extend CtxWrap with @step.Entity::{to_step}

///|
pub extend ComplexInstance with @step.Entity::{to_step}

///|
pub extend GeometricRepresentationContext with @step.Entity::{to_step}

///|
pub extend GlobalUncertaintyAssignedContext with @step.Entity::{to_step}

///|
pub extend GlobalUnitAssignedContext with @step.Entity::{to_step}

///|
pub extend RepresentationContext with @step.Entity::{to_step}
