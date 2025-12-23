///|
// Represents an APPROVAL_PERSON_ORGANIZATION entity.
// Example:
//   APPROVAL_PERSON_ORGANIZATION(#10, #20, #30)
// where #10 is PERSON/ORGANIZATION/PERSON_AND_ORGANIZATION,
// #20 is APPROVAL, and #30 is APPROVAL_ROLE.
pub struct ApprovalPersonOrganization {
  person_organization : @step.Ref
  approval : @step.Ref
  role : @step.Ref
}

///|
pub fn ApprovalPersonOrganization::new(
  person_organization : @step.Ref,
  approval : @step.Ref,
  role : @step.Ref,
) -> ApprovalPersonOrganization {
  ApprovalPersonOrganization::{ person_organization, approval, role }
}

///|
pub impl @step.Entity for ApprovalPersonOrganization with to_step(self) {
  let po_str = "#\{self.person_organization.id.value}"
  let approval_str = "#\{self.approval.id.value}"
  let role_str = "#\{self.role.id.value}"
  "APPROVAL_PERSON_ORGANIZATION(\{po_str},\{approval_str},\{role_str})"
}
