///|
/// components/examples/revolution
///
/// Generate the analytic solids of revolution used to validate the
/// `RevolvedProfile` compiler:
///
/// ```bash
/// moon run --target native components/examples/revolution -- \
///   --out-dir components/examples/output
/// ```
///
/// Each file is one closed STEP solid. The sphere and cap use
/// `SPHERICAL_SURFACE`; the cone uses `CONICAL_SURFACE`; the ring uses
/// cylindrical and planar faces; the torus uses `TOROIDAL_SURFACE`.
async fn main {
  let spec = {
    "out-dir": @cli.opt_string(
      short='o',
      help="Directory for the generated STEP files",
    ),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/revolution",
      description="Generate analytic solids of revolution.",
    )
    is Some(args) else {
    return
  }
  let dir = args.string_opt("out-dir").unwrap_or("components/examples/output")
  @fs.mkdir(dir, recursive=true, allow_exist=true) catch {
    _ => ()
  }
  let jobs : Array[(String, @cad.Shape)] = [
    ("revolution-sphere.step", @cad.RevolvedProfile::sphere(10.0).as_shape()),
    (
      "revolution-dome.step",
      @cad.RevolvedProfile::sphere_cap(4.0, 3.0).as_shape(),
    ),
    ("revolution-cone.step", @cad.RevolvedProfile::cone(4.0, 8.0).as_shape()),
    (
      "revolution-frustum.step",
      @cad.RevolvedProfile::frustum(4.0, 2.0, 6.0).as_shape(),
    ),
    (
      "revolution-cylinder.step",
      @cad.RevolvedProfile::cylinder(10.0, 8.0).as_shape(),
    ),
    ("analytic-cylinder.step", @cad.Cylinder::new(10.0, 8.0)),
    (
      "revolution-ring.step",
      @cad.RevolvedProfile::polyline(
        [(2.0, 0.0), (5.0, 0.0), (5.0, 2.0), (2.0, 2.0)],
        closed=true,
      ).as_shape(),
    ),
    (
      "revolution-torus.step",
      @cad.RevolvedProfile::new([
        @cad.RevArc((4.0, 0.0), (5.0, 1.0), (5.0, 0.0)),
        @cad.RevArc((5.0, 1.0), (6.0, 0.0), (5.0, 0.0)),
        @cad.RevArc((6.0, 0.0), (5.0, -1.0), (5.0, 0.0)),
        @cad.RevArc((5.0, -1.0), (4.0, 0.0), (5.0, 0.0)),
      ]).as_shape(),
    ),
  ]
  for job in jobs {
    let (name, shape) = job
    let path = dir + "/" + name
    let design = @cad.Design::new(name~, documentation="analytic revolve")
    let d = @cad.Design::add(design, shape.with_name(name))
    @cad.Design::write_step(d, Some(path), checked=true)
    @cli.eprintln("wrote " + path)
  }
}
