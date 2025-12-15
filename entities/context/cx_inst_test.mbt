///|
test "ComplexInstance to_step" {
  let parts : Array[ComplexPart] = [
    ComplexPart::GeomRepCtx(GeometricRepresentationContext::new(3)),
    ComplexPart::RepCtx(
      RepresentationContext::new("cube", "TOP_LEVEL_ASSEMBLY_PART"),
    ),
  ]
  let ci = ComplexInstance::new(parts)
  let s = @step.Entity::to_step(ci)
  assert_true(s.has_prefix("(\n"))
  assert_true(s.contains("GEOMETRIC_REPRESENTATION_CONTEXT(3)"))
  assert_true(
    s.contains("REPRESENTATION_CONTEXT('cube','TOP_LEVEL_ASSEMBLY_PART')"),
  )
  assert_true(s.has_suffix("\n)"))
}
