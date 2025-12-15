///|
// Represents an APPLICATION_CONTEXT entity.
// Example from simple-box.step:
//   APPLICATION_CONTEXT('core data for automotive mechanical design processes')
pub struct ApplicationContext {
  application : String
}

///|
pub fn ApplicationContext::new(application : String) -> ApplicationContext {
  ApplicationContext::{ application, }
}

///|
pub impl @step.Entity for ApplicationContext with to_step(self) {
  "APPLICATION_CONTEXT(\{step_str_or_dollar(self.application)})"
}
