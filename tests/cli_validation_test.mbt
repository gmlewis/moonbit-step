///|
// Focused tests for gmlewis/step/cli parsing + validation.

///|
async test "cli_opt_double_exclusive_min" {
  let spec = {
    "edge": @cli.opt_double(
      20.0,
      help="Edge length in millimeters",
      min=0.0,
      min_exclusive=true,
    ),
  }

  // Strictly positive: edge must be > 0.
  inspect(
    @cli.parse(spec, prog="t", cli_args=["--edge", "0"], raise_on_error=false)
    is None,
    content="true",
  )
  inspect(
    @cli.parse(spec, prog="t", cli_args=["--edge", "-1"], raise_on_error=false)
    is None,
    content="true",
  )

  // Also works through the --name=value normalization.
  inspect(
    @cli.parse(spec, prog="t", cli_args=["--edge=-1"], raise_on_error=false)
    is None,
    content="true",
  )

  // Valid value should parse.
  inspect(
    @cli.parse(spec, prog="t", cli_args=["--edge", "0.1"]) is Some(_),
    content="true",
  )
}

///|
async test "cli_negative_numbers_work" {
  let spec = @cli.with_translate({})

  // Negative numeric values should be accepted for named args.
  match @cli.parse(spec, prog="t", cli_args=["--tx", "-1"]) {
    Some(args) => inspect(args.double("tx") == -1.0, content="true")
    None => inspect(false, content="true")
  }

  // Also via --name=value.
  match @cli.parse(spec, prog="t", cli_args=["--ty=-2.5"]) {
    Some(args) => inspect(args.double("ty") == -2.5, content="true")
    None => inspect(false, content="true")
  }

  // And via translate bundle with comma-separated form.
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

  // And via --translate=value.
  match @cli.parse(spec, prog="t", cli_args=["--translate=-1,2,3"]) {
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
}
