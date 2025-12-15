///|
// A distinct type for entity IDs, preventing mix-ups with regular Ints.
pub(all) struct EntityId {
  value : Int
}

///|
// A reference to another entity, holding its ID.
// (TypeScript has `Ref<T>`; we keep the runtime representation unparameterized.)
pub(all) struct Ref {
  id : EntityId
}
