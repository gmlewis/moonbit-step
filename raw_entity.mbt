///|
// Raw STEP entity used to preserve unknown/unmodeled DATA entities.
//
// This is intentionally separate from `UnknownEntity`, which is a placeholder
// type for references whose entity type isn't modeled yet.

///|
pub struct RawEntity {
  name : String
  args : String
}

///|
pub fn RawEntity::new(name : String, args : String) -> RawEntity {
  RawEntity::{ name, args }
}

///|
pub impl Entity for RawEntity with to_step(self) {
  "\{self.name}\{self.args}"
}
