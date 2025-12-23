///|
test "CSG primitives to_step" {
  let pos = @step.Ref::{ id: { value: 10 } }
  let block = Block::new("b", pos, 1.0, 2.0, 3.0)
  inspect(@step.Entity::to_step(block), content="BLOCK('b',#10,1.0,2.0,3.0)")
  let sphere = Sphere::new("s", pos, 5.0)
  inspect(@step.Entity::to_step(sphere), content="SPHERE('s',#10,5.0)")
  let cylinder = RightCircularCylinder::new("cyl", pos, 50.0, 10.0)
  inspect(
    @step.Entity::to_step(cylinder),
    content="RIGHT_CIRCULAR_CYLINDER('cyl',#10,50.0,10.0)",
  )
  let cone = RightCircularCone::new("cone", pos, 50.0, 10.0, 0.5)
  inspect(
    @step.Entity::to_step(cone),
    content="RIGHT_CIRCULAR_CONE('cone',#10,50.0,10.0,0.5)",
  )
  let torus = Torus::new("t", pos, 20.0, 5.0)
  inspect(@step.Entity::to_step(torus), content="TORUS('t',#10,20.0,5.0)")
  let pyramid = RectangularPyramid::new("p", pos, 10.0, 20.0, 30.0)
  inspect(
    @step.Entity::to_step(pyramid),
    content="RECTANGULAR_PYRAMID('p',#10,10.0,20.0,30.0)",
  )
  let wedge = RightAngularWedge::new("w", pos, 10.0, 20.0, 30.0, 5.0)
  inspect(
    @step.Entity::to_step(wedge),
    content="RIGHT_ANGULAR_WEDGE('w',#10,10.0,20.0,30.0,5.0)",
  )
}
