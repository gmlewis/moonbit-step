///|
// Represents a PERSON_AND_ORGANIZATION entity.
// Example:
//   PERSON_AND_ORGANIZATION(#10, #20)
// where #10 is a PERSON and #20 is an ORGANIZATION.
pub struct PersonAndOrganization {
  the_person : @step.Ref
  the_organization : @step.Ref
}

///|
pub fn PersonAndOrganization::new(
  the_person : @step.Ref,
  the_organization : @step.Ref,
) -> PersonAndOrganization {
  PersonAndOrganization::{ the_person, the_organization }
}

///|
pub impl @step.Entity for PersonAndOrganization with to_step(self) {
  let person_str = "#\{self.the_person.id.value}"
  let org_str = "#\{self.the_organization.id.value}"
  "PERSON_AND_ORGANIZATION(\{person_str},\{org_str})"
}
