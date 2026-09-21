///|
// Explicit trait-method promotion declarations.
//
// MoonBit no longer promotes a trait's methods to direct methods on a type
// implicitly: every promoted method needs an explicit `extend` declaration,
// otherwise moonc warns (implicit_impl_as_method). `Entity::to_step` is this
// package's public API, so it is promoted plainly.

///|
pub extend AdvancedFace with @step.Entity::{to_step}

///|
pub extend BrepWithVoids with @step.Entity::{to_step}

///|
pub extend ClosedShell with @step.Entity::{to_step}

///|
pub extend ConnectedFaceSet with @step.Entity::{to_step}

///|
pub extend EdgeCurve with @step.Entity::{to_step}

///|
pub extend EdgeLoop with @step.Entity::{to_step}

///|
pub extend FaceBound with @step.Entity::{to_step}

///|
pub extend FaceOuterBound with @step.Entity::{to_step}

///|
pub extend FaceSurface with @step.Entity::{to_step}

///|
pub extend ManifoldSolidBrep with @step.Entity::{to_step}

///|
pub extend OpenShell with @step.Entity::{to_step}

///|
pub extend OrientedEdge with @step.Entity::{to_step}

///|
pub extend ShellBasedSurfaceModel with @step.Entity::{to_step}

///|
pub extend Subface with @step.Entity::{to_step}

///|
pub extend VertexPoint with @step.Entity::{to_step}
