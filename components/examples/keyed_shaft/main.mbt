///|
/// components/examples/keyed_shaft
///
/// Generate a shaft with a real rectangular keyway and a matching key:
///
/// ```bash
/// moon run --target native components/examples/keyed_shaft -- \
///   --diameter 20 --length 40 --keywayWidth 6 --keywayDepth 3.5 -o keyed.step
/// ```
///
/// The keyway is a geometric notch in the extruded section, not a nominal
/// boolean subtraction.
async fn main {
  let spec = {
    "diameter": @cli.opt_double(
      20.0,
      short='d',
      help="Shaft diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "length": @cli.opt_double(
      40.0,
      short='l',
      help="Shaft length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "keywayWidth": @cli.opt_double(
      6.0,
      short='w',
      help="Keyway width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "keywayDepth": @cli.opt_double(
      3.5,
      short='e',
      help="Keyway depth from the shaft surface in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "keyLength": @cli.opt_double(
      20.0,
      short='k',
      help="Key length in mm (with clearance to the shaft ends)",
      min=0.0,
    ),
    "noKey": @cli.flag(help="Write only the keyed shaft"),
    "mode": @cli.opt_string(
      short='M',
      help="Output mode: flat (default) or assembly",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the assembly bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/keyed_shaft",
      description="Generate a keyed shaft and a matching key.",
    )
    is Some(args) else {
    return
  }
  let diameter = args.double("diameter")
  let length = args.double("length")
  let keyway_width = args.double("keywayWidth")
  let keyway_depth = args.double("keywayDepth")
  let shaft = match
    @motion.keyed_shaft(diameter, length, keyway_width, keyway_depth) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let mut assembly = @assemblies.Assembly::new(
    name="keyed-shaft",
    description="Keyed shaft with a real rectangular keyway and a matching key.",
  ).add(shaft, instance_name="shaft")
  if !args.flag("noKey") {
    let key_length = args.double("keyLength")
    let key = match
      @motion.key_for_keyway(keyway_width, keyway_depth, key_length) {
      Ok(c) => c
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
    let key_width = keyway_width - 0.1
    let x = -key_width / 2.0
    let y = diameter / 2.0 - keyway_depth
    let z = (length - key_length) / 2.0
    assembly = assembly.add(
      key,
      placement=@common.Placement::at(x, y, z),
      instance_name="key",
    )
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = assembly.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  match args.string_opt("mode").unwrap_or("flat") {
    "assembly" => assembly.write_assembly_step(args.string_opt("out"))
    "flat" => assembly.write_step(args.string_opt("out"), checked=true)
    other => {
      @cli.eprintln("error: unsupported mode: " + other)
      abort("")
    }
  }
}
