///|
// Represents a STEP Part 21 complex entity instance wrapper.
//
// Example (from simple-box.step):
//   #187=(
//     GEOMETRIC_REPRESENTATION_CONTEXT(3)
//     GLOBAL_UNCERTAINTY_ASSIGNED_CONTEXT((#188))
//     GLOBAL_UNIT_ASSIGNED_CONTEXT((#194,#190,#189))
//     REPRESENTATION_CONTEXT('cube','TOP_LEVEL_ASSEMBLY_PART')
//   );
//
// We preserve the raw parenthesized body so it round-trips.
pub struct CtxWrap {
  raw : String
}

///|
pub fn CtxWrap::new(raw : String) -> CtxWrap {
  CtxWrap::{ raw, }
}

///|
pub impl @step.Entity for CtxWrap with to_step(self) {
  self.raw
}
