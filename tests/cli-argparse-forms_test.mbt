///|
// Tests for @cli translate-bundle forms and @argparse-specific behaviors.

///|
async test "cli_translate_forms" {
  let spec = @cli.with_translate(Map([]))

  // Multi-token form: -t 1 2 3.
  match @cli.parse(spec, prog="t", cli_args=["-t", "1", "2", "3"]) {
    Some(args) =>
      match args.translate_xyz() {
        Some((x, y, z)) => {
          inspect(x == 1.0, content="true")
          inspect(y == 2.0, content="true")
          inspect(z == 3.0, content="true")
        }
        None => inspect(false, content="true")
      }
    None => inspect(false, content="true")
  }

  // Comma bundle with negatives: -t -1,2,3.
  match @cli.parse(spec, prog="t", cli_args=["-t", "-1,2,3"]) {
    Some(args) =>
      match args.translate_xyz() {
        Some((x, y, z)) => {
          inspect(x == -1.0, content="true")
          inspect(y == 2.0, content="true")
          inspect(z == 3.0, content="true")
        }
        None => inspect(false, content="true")
      }
    None => inspect(false, content="true")
  }

  // Multi-token negatives: -t -1 -2 -3.
  match @cli.parse(spec, prog="t", cli_args=["-t", "-1", "-2", "-3"]) {
    Some(args) =>
      match args.translate_xyz() {
        Some((x, y, z)) => {
          inspect(x == -1.0, content="true")
          inspect(y == -2.0, content="true")
          inspect(z == -3.0, content="true")
        }
        None => inspect(false, content="true")
      }
    None => inspect(false, content="true")
  }

  // Quoted whitespace form: -t "1 2 3".
  match @cli.parse(spec, prog="t", cli_args=["-t", "1 2 3"]) {
    Some(args) =>
      match args.translate_xyz() {
        Some((x, y, z)) => {
          inspect(x == 1.0, content="true")
          inspect(y == 2.0, content="true")
          inspect(z == 3.0, content="true")
        }
        None => inspect(false, content="true")
      }
    None => inspect(false, content="true")
  }

  // Bare -t falls back to --tx/--ty/--tz.
  match @cli.parse(spec, prog="t", cli_args=["-t", "--tx", "5"]) {
    Some(args) =>
      match args.translate_xyz() {
        Some((x, y, z)) => {
          inspect(x == 5.0, content="true")
          inspect(y == 0.0, content="true")
          inspect(z == 0.0, content="true")
        }
        None => inspect(false, content="true")
      }
    None => inspect(false, content="true")
  }

  // A bare value option followed by another option gets dropped, not
  // swallowed: --tx --ty 2 leaves tx at its default.
  match @cli.parse(spec, prog="t", cli_args=["--tx", "--ty", "2"]) {
    Some(args) => {
      inspect(args.double("tx") == 0.0, content="true")
      inspect(args.double("ty") == 2.0, content="true")
    }
    None => inspect(false, content="true")
  }
}

///|
async test "cli_flags_and_unknown_args" {
  let spec = {
    "debug": @cli.flag(short='d', help="Debug"),
    "out": @cli.opt_string(short='o', help="Output file"),
    "count": @cli.opt_int(1, help="Count", min=1),
  }

  // Short flag + short option + defaults.
  match @cli.parse(spec, prog="t", cli_args=["-d", "-o", "out.step"]) {
    Some(args) => {
      inspect(args.flag("debug"), content="true")
      inspect(args.bool_opt("debug"), content="true")
      inspect(args.string_opt("out") == Some("out.step"), content="true")
      inspect(args.int("count") == 1, content="true")
    }
    None => inspect(false, content="true")
  }

  // Untouched flag defaults to false.
  match @cli.parse(spec, prog="t", cli_args=["--count", "2"]) {
    Some(args) => {
      inspect(args.flag("debug"), content="false")
      inspect(args.string_opt("out") is None, content="true")
    }
    None => inspect(false, content="true")
  }

  // Unknown option fails to parse.
  inspect(
    @cli.parse(spec, prog="t", cli_args=["--nope"], raise_on_error=false)
    is None,
    content="true",
  )

  // int min validation.
  inspect(
    @cli.parse(spec, prog="t", cli_args=["--count", "0"], raise_on_error=false)
    is None,
    content="true",
  )
  inspect(
    @cli.parse(spec, prog="t", cli_args=["--count", "3"]) is Some(_),
    content="true",
  )
}
