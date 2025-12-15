///|
// Placeholder type used when the referenced entity type is not modeled yet.
// (Previously used as `Ref[T]`'s type parameter; kept for compatibility and clarity.)
pub struct UnknownEntity {}

///|
// Ensure the struct is constructed at least once (keeps `moon info` warning-free).
pub let unknown_entity_witness : UnknownEntity = UnknownEntity::{  }
