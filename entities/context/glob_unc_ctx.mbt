///|
// Represents a GLOBAL_UNCERTAINTY_ASSIGNED_CONTEXT entity.
// In fixtures this appears inside a complex instance as:
//   GLOBAL_UNCERTAINTY_ASSIGNED_CONTEXT((#188))
pub struct GlobalUncertaintyAssignedContext {
  uncertainties : Array[@step.EntityId]
}

///|
pub fn GlobalUncertaintyAssignedContext::new(
  uncertainties : Array[@step.EntityId],
) -> GlobalUncertaintyAssignedContext {
  GlobalUncertaintyAssignedContext::{ uncertainties, }
}

///|
pub impl @step.Entity for GlobalUncertaintyAssignedContext with to_step(self) {
  let refs = self.uncertainties.map(fn(id) { "#\{id.value}" }).join(",")
  "GLOBAL_UNCERTAINTY_ASSIGNED_CONTEXT((\{refs}))"
}
