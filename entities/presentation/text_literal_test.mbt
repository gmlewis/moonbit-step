///|
test "TextLiteral::to_step" {
  let placement = @step.Ref::{ id: { value: 10 } }
  let font = @step.Ref::{ id: { value: 20 } }
  let tl = TextLiteral::new(
    "name",
    "literal",
    placement,
    "alignment",
    Right,
    font,
  )
  let s = @step.Entity::to_step(tl)
  inspect(
    s,
    content="TEXT_LITERAL('name','literal',#10,'alignment',.RIGHT.,#20)",
  )
}

///|
test "TextPath::to_step" {
  inspect(@step.Entity::to_step(TextPath::Left), content=".LEFT.")
  inspect(@step.Entity::to_step(TextPath::Right), content=".RIGHT.")
  inspect(@step.Entity::to_step(TextPath::Up), content=".UP.")
  inspect(@step.Entity::to_step(TextPath::Down), content=".DOWN.")
}
