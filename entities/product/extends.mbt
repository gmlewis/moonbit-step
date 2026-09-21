///|
// Explicit trait-method promotion declarations.
//
// MoonBit no longer promotes a trait's methods to direct methods on a type
// implicitly: every promoted method needs an explicit `extend` declaration,
// otherwise moonc warns (implicit_impl_as_method). `Entity::to_step` is this
// package's public API, so it is promoted plainly.

///|
pub extend AdvancedBrepShapeRepresentation with @step.Entity::{to_step}

///|
pub extend ApplicationContext with @step.Entity::{to_step}

///|
pub extend ApplicationProtocolDefinition with @step.Entity::{to_step}

///|
pub extend Approval with @step.Entity::{to_step}

///|
pub extend ApprovalPersonOrganization with @step.Entity::{to_step}

///|
pub extend ApprovalRole with @step.Entity::{to_step}

///|
pub extend ApprovalStatus with @step.Entity::{to_step}

///|
pub extend CalendarDate with @step.Entity::{to_step}

///|
pub extend CertificationType with @step.Entity::{to_step}

///|
pub extend Certification with @step.Entity::{to_step}

///|
pub extend CsgShapeRepresentation with @step.Entity::{to_step}

///|
pub extend ContextDependentShapeRepresentation with @step.Entity::{to_step}

///|
pub extend DateAndTime with @step.Entity::{to_step}

///|
pub extend DescriptiveRepresentationItem with @step.Entity::{to_step}

///|
pub extend DocumentReference with @step.Entity::{to_step}

///|
pub extend Document with @step.Entity::{to_step}

///|
pub extend DocumentType with @step.Entity::{to_step}

///|
pub extend ItemDefinedTransformation with @step.Entity::{to_step}

///|
pub extend LocalTime with @step.Entity::{to_step}

///|
pub extend MeasureRepresentationItem with @step.Entity::{to_step}

///|
pub extend NextAssemblyUsageOccurrence with @step.Entity::{to_step}

///|
pub extend Organization with @step.Entity::{to_step}

///|
pub extend Person with @step.Entity::{to_step}

///|
pub extend PersonAndOrganization with @step.Entity::{to_step}

///|
pub extend ProductDefinitionFormation with @step.Entity::{to_step}

///|
pub extend ProductDefinitionShape with @step.Entity::{to_step}

///|
pub extend ProductDefinitionFormationWithSpecifiedSource with @step.Entity::{
  to_step,
}

///|
pub extend ProductRelatedProductCategory with @step.Entity::{to_step}

///|
pub extend Product with @step.Entity::{to_step}

///|
pub extend ProductContext with @step.Entity::{to_step}

///|
pub extend ProductDefinition with @step.Entity::{to_step}

///|
pub extend ProductDefinitionContext with @step.Entity::{to_step}

///|
pub extend PropertyDefinition with @step.Entity::{to_step}

///|
pub extend PropertyDefinitionRepresentation with @step.Entity::{to_step}

///|
pub extend RepresentationRelationship with @step.Entity::{to_step}

///|
pub extend RepresentationRelationshipWithTransformation with @step.Entity::{
  to_step,
}

///|
pub extend Representation with @step.Entity::{to_step}

///|
pub extend SecurityClassification with @step.Entity::{to_step}

///|
pub extend SecurityClassificationLevel with @step.Entity::{to_step}

///|
pub extend ShapeAspect with @step.Entity::{to_step}

///|
pub extend ShapeDefinitionRepresentation with @step.Entity::{to_step}

///|
pub extend ShapeRepresentation with @step.Entity::{to_step}

///|
pub extend ShapeRepresentationRelationship with @step.Entity::{to_step}

///|
pub extend CoordinatedUniversalTimeOffset with @step.Entity::{to_step}
