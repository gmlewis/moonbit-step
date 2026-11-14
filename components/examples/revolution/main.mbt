///|
/// components/examples/revolution
///
/// Generate the analytic solids of revolution used to validate the
/// `RevolvedProfile` compiler:
///
/// ```bash
/// moon run components/examples/revolution -- \
///   --out-dir components/examples/output
/// moon run components/examples/revolution -- \
///   -o revolution-gallery.step
/// ```
///
/// With a `.step`/`.stp` output path the example writes one combined gallery
/// (all eight solids spaced along X), which is what the `--view` wrapper opens.
/// With a directory it writes one file per solid. Each solid is closed; the
/// sphere and cap use `SPHERICAL_SURFACE`, the cone `CONICAL_SURFACE`, the ring
/// cylindrical/planar faces, and the torus `TOROIDAL_SURFACE`.
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
  let out_path = args
    .string_opt("out-dir")
    .unwrap_or("components/examples/output")
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
  if out_path.has_suffix(".step") || out_path.has_suffix(".stp") {
    let mut design = @cad.Design::new(
      name="revolution-gallery",
      documentation="analytic solids of revolution gallery",
    )
    for i, job in jobs {
      let (name, shape) = job
      let node = shape.with_name(name).translate(x=26.0 * i.to_double())
      design = @cad.Design::add(design, node)
    }
    @cad.Design::write_step(design, Some(out_path), checked=true)
    @cli.eprintln("wrote " + out_path)
    return
  }
  @fs.mkdir(out_path, recursive=true, allow_exist=true) catch {
    _ => ()
  }
  for job in jobs {
    let (name, shape) = job
    let path = out_path + "/" + name
    let design = @cad.Design::new(name~, documentation="analytic revolve")
    let d = @cad.Design::add(design, shape.with_name(name))
    @cad.Design::write_step(d, Some(path), checked=true)
    @cli.eprintln("wrote " + path)
  }
}
