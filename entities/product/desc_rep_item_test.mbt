///|
test "descriptive_representation_item to_step" {
  let entity = DescriptiveRepresentationItem::new("Steel", "Steel")
  inspect(
    entity.to_step(),
    content="DESCRIPTIVE_REPRESENTATION_ITEM('Steel','Steel')",
  )
}
