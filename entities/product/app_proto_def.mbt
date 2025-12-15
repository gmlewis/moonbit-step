///|
// Represents an APPLICATION_PROTOCOL_DEFINITION entity.
// Example from simple-box.step:
//   APPLICATION_PROTOCOL_DEFINITION('international standard','automotive_design',2010,#21)
pub struct ApplicationProtocolDefinition {
  status : String
  application_interpreted_model_schema_name : String
  application_protocol_year : Int
  application : @step.Ref
}

///|
pub fn ApplicationProtocolDefinition::new(
  status : String,
  application_interpreted_model_schema_name : String,
  application_protocol_year : Int,
  application : @step.Ref,
) -> ApplicationProtocolDefinition {
  ApplicationProtocolDefinition::{
    status,
    application_interpreted_model_schema_name,
    application_protocol_year,
    application,
  }
}

///|
pub impl @step.Entity for ApplicationProtocolDefinition with to_step(self) {
  let year_str = Int::to_string(self.application_protocol_year)
  let app_str = "#\{self.application.id.value}"
  "APPLICATION_PROTOCOL_DEFINITION(\{step_str_or_dollar(self.status)},\{step_str_or_dollar(self.application_interpreted_model_schema_name)},\{year_str},\{app_str})"
}
