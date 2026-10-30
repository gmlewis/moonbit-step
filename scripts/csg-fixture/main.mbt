///|
/// Writes a small CSG STEP fixture for scripts/csg_eval_test.py.
///
/// Usage: moon run scripts/csg-fixture -- <out.step>
///
/// The design is a base block with two drilled cutters (a DIFFERENCE) unioned
/// with a separate tab, so the tree contains a nested boolean operand.
async fn main {
  let base = @cad.Cuboid::new(20.0, 20.0, 5.0).with_name("base")
  let c1 = @cad.Cuboid::new(4.0, 4.0, 10.0).with_name("c1").translate(z=-2.0)
  let c2 = @cad.Cuboid::new(4.0, 4.0, 10.0)
    .with_name("c2")
    .translate(x=10.0, z=-2.0)
  let cut = @cad.difference(base, [c1, c2], name="cut")
  let tab = @cad.Cuboid::new(6.0, 6.0, 6.0).with_name("tab").translate(x=30.0)
  let design = @cad.Design::new(name="csg-fixture").add(
    @cad.union_all([cut, tab], name="fixture"),
  )
  let args = @env.args()
  let out = if args.length() > 1 { Some(args[1]) } else { None }
  design.write_csg_step(out)
}
