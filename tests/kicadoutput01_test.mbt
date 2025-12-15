///|
async test "can_parse_kicadoutput01_roundtrip_from_file" {
  let repo = @parse.parse_repository_from_file(
    "tests/testdata/kicadoutput01.step",
  )
  let repo_len = repo.len()
  let data_section = repo.to_step_data_section()
  inspect(repo_len > 0, content="true")

  // Basic presence checks for entities that were previously missing.
  let has_toroidal_surface = match
    String::find(data_section, "TOROIDAL_SURFACE") {
    Some(_) => true
    None => false
  }
  inspect(has_toroidal_surface, content="true")
  let has_context_dependent = match
    String::find(data_section, "CONTEXT_DEPENDENT_SHAPE_REPRESENTATION") {
    Some(_) => true
    None => false
  }
  inspect(has_context_dependent, content="true")

  // Spot-check a few known lines from the fixture.
  let has_toroidal_surface_97 = match
    String::find(data_section, "#97=TOROIDAL_SURFACE('',#98,0.4,0.4);") {
    Some(_) => true
    None => false
  }
  inspect(has_toroidal_surface_97, content="true")
  let has_cdsr_433 = match
    String::find(
      data_section, "#433=CONTEXT_DEPENDENT_SHAPE_REPRESENTATION(#434,#436);",
    ) {
    Some(_) => true
    None => false
  }
  inspect(has_cdsr_433, content="true")
  let has_idt_435 = match
    String::find(
      data_section, "#435=ITEM_DEFINED_TRANSFORMATION('','',#11,#15);",
    ) {
    Some(_) => true
    None => false
  }
  inspect(has_idt_435, content="true")
  let has_nauo_437 = match
    String::find(
      data_section, "#437=NEXT_ASSEMBLY_USAGE_OCCURRENCE('1','R2',$,#5,#35,$);",
    ) {
    Some(_) => true
    None => false
  }
  inspect(has_nauo_437, content="true")
}
