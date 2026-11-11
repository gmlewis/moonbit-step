///|
/// components/examples/fasteners
///
/// Generate one metric fastener as a STEP file:
///
/// ```bash
/// moon run components/examples/fasteners -- \
///   --standard iso4762 --size M4 --length 20 --detail detailed -o M4x20.step
/// ```
///
/// The example is deliberately small: the component packages do the modeling,
/// and this program only parses parameters and writes the result.
async fn main {
  let spec = {
    "standard": @cli.opt_string(
      short='s',
      help="Standard: iso4762, iso4032, iso7089, din125, din127, din440, din7349, din913, din93, iso4017, iso4014, iso7380, iso10642, din976",
    ),
    "size": @cli.opt_string(short='m', help="Metric size, e.g. M3, M4, M5"),
    "length": @cli.opt_double(
      20.0,
      short='l',
      help="Length in mm for screws and threaded rods",
      min=0.0,
      min_exclusive=true,
    ),
    "detail": @cli.opt_string(
      short='d',
      help="Detail: simplified, detailed, full",
    ),
    "threads": @cli.opt_string(
      short='t',
      help="Thread representation: none, helical (overrides --detail)",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "catalog": @cli.opt_string(
      short='c',
      help="Generate the built-in M3/M4/M5 catalog into this directory",
    ),
    "bbox": @cli.flag(help="Print the component bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/fasteners",
      description="Generate one metric fastener STEP model.",
    )
    is Some(args) else {
    return
  }
  match args.string_opt("catalog") {
    Some(dir) => {
      generate_catalog(dir)
      return
    }
    None => ()
  }
  let standard = args.string_opt("standard").unwrap_or("iso4762")
  let size_text = args.string_opt("size").unwrap_or("M4")
  let size = match @standards.MetricSize::parse(size_text) {
    Some(s) => s
    None => {
      @cli.eprintln("error: unsupported metric size: " + size_text)
      abort("")
    }
  }
  let length = args.double("length")
  let detail = parse_detail(args.string_opt("detail").unwrap_or("simplified"))
  let threads = parse_threads(args.string_opt("threads"))
  let result : Result[@common.Component, @common.SpecError] = match standard {
    "iso4762" =>
      match threads {
        Some(t) => @fcomponents.iso4762_screw(size, length, detail~, threads=t)
        None => @fcomponents.iso4762_screw(size, length, detail~)
      }
    "iso4032" =>
      match threads {
        Some(t) => @fcomponents.iso4032_nut(size, detail~, threads=t)
        None => @fcomponents.iso4032_nut(size, detail~)
      }
    "iso7089" => @fcomponents.iso7089_washer(size, detail~)
    "din125" => @fcomponents.din125_washer(size, detail~)
    "din127" => @fcomponents.din127_washer(size, detail~)
    "din440" => @fcomponents.din440_washer(size, detail~)
    "din7349" => @fcomponents.din7349_washer(size, detail~)
    "din913" => @fcomponents.din913(size, length, detail~)
    "din93" => @fcomponents.din93_tab_washer(size, detail~)
    "iso7380" =>
      match threads {
        Some(t) => @fcomponents.iso7380_screw(size, length, detail~, threads=t)
        None => @fcomponents.iso7380_screw(size, length, detail~)
      }
    "iso10642" =>
      match threads {
        Some(t) => @fcomponents.iso10642_screw(size, length, detail~, threads=t)
        None => @fcomponents.iso10642_screw(size, length, detail~)
      }
    "iso4017" =>
      match threads {
        Some(t) => @fcomponents.iso4017(size, length, detail~, threads=t)
        None => @fcomponents.iso4017(size, length, detail~)
      }
    "iso4014" =>
      match threads {
        Some(t) => @fcomponents.iso4014(size, length, detail~, threads=t)
        None => @fcomponents.iso4014(size, length, detail~)
      }
    "din976" =>
      match threads {
        Some(t) => @fcomponents.din976(size, length, detail~, threads=t)
        None => @fcomponents.din976(size, length, detail~)
      }
    other => {
      @cli.eprintln("error: unsupported standard: " + other)
      abort("")
    }
  }
  let component = match result {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  let out_path = args.string_opt("out")
  component.write_step(out_path, checked=true)
}

///|
fn parse_detail(text : String) -> @common.DetailLevel {
  match text {
    "simplified" => @common.DetailLevel::Simplified
    "detailed" => @common.DetailLevel::Detailed
    "full" | "fully-modeled" | "fullymodeled" =>
      @common.DetailLevel::FullyModeled
    _ => @common.DetailLevel::Simplified
  }
}

///|
fn parse_threads(text : String?) -> @common.ThreadRepresentation? {
  match text {
    None => None
    Some(value) =>
      match value {
        "none" => Some(@common.ThreadRepresentation::None)
        "helical" | "modeled" => Some(@common.ThreadRepresentation::Helical)
        "cosmetic" => Some(@common.ThreadRepresentation::Cosmetic)
        _ => None
      }
  }
}

///|
fn catalog_sizes() -> Array[@standards.MetricSize] {
  [@standards.M3, @standards.M4, @standards.M5]
}

///|
fn catalog_screw_lengths(size : @standards.MetricSize) -> Array[Double] {
  match size {
    @standards.M3 => [8.0, 12.0, 20.0]
    @standards.M4 => [10.0, 16.0, 20.0, 30.0]
    @standards.M5 => [12.0, 20.0, 25.0]
    _ => [size.nominal_diameter_mm() * 5.0]
  }
}

///|
async fn write_component(
  dir : String,
  stem : String,
  component : @common.Component,
) -> Unit {
  let path = dir + "/" + stem + ".step"
  @cli.eprintln("writing " + path)
  component.write_step(Some(path), checked=true)
}

///|
async fn generate_catalog(dir : String) -> Unit {
  for size in catalog_sizes() {
    let size_token = size.designation()
    for length in catalog_screw_lengths(size) {
      let screw = match @fcomponents.iso4762_screw(size, length) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
      let length_token = @fcomponents.format_length(length)
      write_component(dir, "iso4762-" + size_token + "x" + length_token, screw)
    }
    let nut = match @fcomponents.iso4032_nut(size) {
      Ok(c) => c
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
    write_component(dir, "iso4032-" + size_token, nut)
    let washer = match @fcomponents.iso7089_washer(size) {
      Ok(c) => c
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
    write_component(dir, "iso7089-" + size_token, washer)
  }
  let hex_screw = match @fcomponents.iso4017(@standards.M5, 20.0) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  write_component(dir, "iso4017-M5x20", hex_screw)
  let hex_bolt = match @fcomponents.iso4014(@standards.M8, 40.0) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  write_component(dir, "iso4014-M8x40", hex_bolt)
  let rod = match @fcomponents.din976(@standards.M8, 200.0) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  write_component(dir, "din976-M8x200", rod)
  // One fully modeled showcase for each required size.
  for size in catalog_sizes() {
    let token = size.designation()
    let nut = match
      @fcomponents.iso4032_nut(size, detail=@common.DetailLevel::FullyModeled) {
      Ok(c) => c
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
    write_component(dir, "iso4032-" + token + "-fully-modeled", nut)
  }
  let screw = match
    @fcomponents.iso4762_screw(
      @standards.M4,
      20.0,
      detail=@common.DetailLevel::FullyModeled,
    ) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  write_component(dir, "iso4762-M4x20-fully-modeled", screw)
}
