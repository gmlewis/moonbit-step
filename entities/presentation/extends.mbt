///|
// Explicit trait-method promotion declarations.
//
// MoonBit no longer promotes a trait's methods to direct methods on a type
// implicitly: every promoted method needs an explicit `extend` declaration,
// otherwise moonc warns (implicit_impl_as_method). `Entity::to_step` is this
// package's public API, so it is promoted plainly.

///|
pub extend AnnotationOccurrence with @step.Entity::{to_step}

///|
pub extend ColorRgb with @step.Entity::{to_step}

///|
pub extend FillAreaStyle with @step.Entity::{to_step}

///|
pub extend FillAreaStyleColor with @step.Entity::{to_step}

///|
pub extend HiddenElementOverRidingStyledItem with @step.Entity::{to_step}

///|
pub extend MechanicalDesignGeometricPresentationRepresentation with @step.Entity::{
  to_step,
}

///|
pub extend OverRidingStyledItem with @step.Entity::{to_step}

///|
pub extend DraughtingPreDefinedColour with @step.Entity::{to_step}

///|
pub extend PresentationLayerAssignment with @step.Entity::{to_step}

///|
pub extend PresentationStyleAssignment with @step.Entity::{to_step}

///|
pub extend StyledItem with @step.Entity::{to_step}

///|
pub extend SurfaceSideStyle with @step.Entity::{to_step}

///|
pub extend SurfaceStyleFillArea with @step.Entity::{to_step}

///|
pub extend SurfaceStyleUsage with @step.Entity::{to_step}

///|
pub extend TextPath with @step.Entity::{to_step}

///|
pub extend TextLiteral with @step.Entity::{to_step}
