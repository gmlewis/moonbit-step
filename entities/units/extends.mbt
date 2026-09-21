///|
// Explicit trait-method promotion declarations.
//
// MoonBit no longer promotes a trait's methods to direct methods on a type
// implicitly: every promoted method needs an explicit `extend` declaration,
// otherwise moonc warns (implicit_impl_as_method). `Entity::to_step` is this
// package's public API, so it is promoted plainly.

///|
pub extend ConversionBasedUnit with @step.Entity::{to_step}

///|
pub extend DerivedUnit with @step.Entity::{to_step}

///|
pub extend DimensionalExponents with @step.Entity::{to_step}

///|
pub extend DerivedUnitElement with @step.Entity::{to_step}

///|
pub extend LengthUnit with @step.Entity::{to_step}

///|
pub extend MassUnit with @step.Entity::{to_step}

///|
pub extend MeasureWithUnit with @step.Entity::{to_step}

///|
pub extend NamedUnit with @step.Entity::{to_step}

///|
pub extend PlaneAngleMeasureWithUnit with @step.Entity::{to_step}

///|
pub extend PlaneAngleUnit with @step.Entity::{to_step}

///|
pub extend PositiveRatioMeasure with @step.Entity::{to_step}

///|
pub extend SiUnit with @step.Entity::{to_step}

///|
pub extend SolidAngleUnit with @step.Entity::{to_step}

///|
pub extend UncertaintyMeasureWithUnit with @step.Entity::{to_step}
