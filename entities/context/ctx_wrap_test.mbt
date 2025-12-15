///|
test "ctx_wrap_to_step_preserves_raw" {
  let raw = "(\nGEOMETRIC_REPRESENTATION_CONTEXT(3)\nREPRESENTATION_CONTEXT('cube','TOP_LEVEL_ASSEMBLY_PART')\n)"
  let w = CtxWrap::new(raw)
  inspect(@step.Entity::to_step(w), content=raw)
}
