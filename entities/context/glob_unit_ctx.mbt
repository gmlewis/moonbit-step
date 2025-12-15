///|
// Represents a GLOBAL_UNIT_ASSIGNED_CONTEXT entity.
// In fixtures this appears inside a complex instance as:
//   GLOBAL_UNIT_ASSIGNED_CONTEXT((#194,#190,#189))
pub struct GlobalUnitAssignedContext {
  units : Array[@step.EntityId]
}

///|
pub fn GlobalUnitAssignedContext::new(
  units : Array[@step.EntityId],
) -> GlobalUnitAssignedContext {
  GlobalUnitAssignedContext::{ units, }
}

///|
pub impl @step.Entity for GlobalUnitAssignedContext with to_step(self) {
  let refs = self.units.map(fn(id) { "#\{id.value}" }).join(",")
  "GLOBAL_UNIT_ASSIGNED_CONTEXT((\{refs}))"
}
