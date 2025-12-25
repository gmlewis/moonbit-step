///|
// Tiny convenience wrapper around TheWaWaR/clap.
//
// Goals:
// - Examples don't need to pass @env.args() around.
// - Examples don't need to remember to strip argv[0].
// - Keep the full power of clap available when needed.

///|
// Common option helpers.

fn nan() -> Double {
  0.0 / 0.0
}

///|
fn is_nan(x : Double) -> Bool {
  x != x
}

///|
// TheWaWaR/clap treats any token beginning with ASCII '-' as an argument name.
// To allow negative numbers like "--tx -1", we rewrite the leading '-' into a
// Unicode minus (U+2212) before parsing, then decode it back before numeric
// conversion.
fn decode_cli_minus(s : String) -> String {
  if s.length() >= 1 && cu_at(s, 0) == Char::to_int('−') {
    "-" + substr(s, 1, s.length())
  } else {
    s
  }
}

///|
fn parse_cli_double(s : String) -> Double raise @strconv.StrConvError {
  @strconv.parse_double(decode_cli_minus(s.trim().to_string()))
}

///|
// Argument specification wrapper.
//
// This lets @cli validate numeric ranges (min/max) without requiring callers
// to write manual checks.
pub struct Arg {
  clap : @clap.Arg
  min : Double
  max : Double
  min_exclusive : Bool
  max_exclusive : Bool
}

///|
pub fn opt_int(
  default : Int,
  short? : Char = '\u0000',
  help? : String = "",
  min? : Int,
  max? : Int,
) -> Arg {
  let clap = @clap.Arg::named(
    short~,
    nargs=@clap.Fixed(1),
    defaults=[default.to_string()],
    help~,
  )
  let min = match min {
    Some(v) => v.to_double()
    None => nan()
  }
  let max = match max {
    Some(v) => v.to_double()
    None => nan()
  }
  Arg::{ clap, min, max, min_exclusive: false, max_exclusive: false }
}

///|
pub fn opt_double(
  default : Double,
  short? : Char = '\u0000',
  help? : String = "",
  min? : Double = nan(),
  max? : Double = nan(),
  min_exclusive? : Bool = false,
  max_exclusive? : Bool = false,
) -> Arg {
  let clap = @clap.Arg::named(
    short~,
    nargs=@clap.Fixed(1),
    defaults=[default.to_string()],
    help~,
  )
  Arg::{ clap, min, max, min_exclusive, max_exclusive }
}

///|
pub fn opt_string(short? : Char = '\u0000', help? : String = "") -> Arg {
  // clap validates nargs against defaults even when an option is absent.
  // Using Range(0,1) keeps this option optional without requiring defaults.
  // Note: clap's Range upper bound behaves like an exclusive limit.
  // Range(0,2) allows 0 or 1 values.
  let clap = @clap.Arg::named(short~, nargs=@clap.Range(0, 2), help~)
  Arg::{
    clap,
    min: nan(),
    max: nan(),
    min_exclusive: false,
    max_exclusive: false,
  }
}

///|
pub fn flag(short? : Char = '\u0000', help? : String = "") -> Arg {
  let clap = @clap.Arg::flag(short~, help~)
  Arg::{
    clap,
    min: nan(),
    max: nan(),
    min_exclusive: false,
    max_exclusive: false,
  }
}

///|
// Convenience for `--name <x> <y> <z>`.
pub fn opt_vec3(short? : Char = '\u0000', help? : String = "") -> Arg {
  // clap validates nargs against defaults even when an option is absent.
  // Using Range(0,3) keeps this option optional, while callers can enforce
  // either 0 or 3 values for a good UX.
  // Note: clap's Range upper bound behaves like an exclusive limit.
  // Range(0,4) allows 0..3 values.
  let clap = @clap.Arg::named(short~, nargs=@clap.Range(0, 4), help~)
  Arg::{
    clap,
    min: nan(),
    max: nan(),
    min_exclusive: false,
    max_exclusive: false,
  }
}

///|
// Parsed values wrapper.
pub struct Args {
  value : @clap.SimpleValue
}

///|
fn substr(s : String, start : Int, end : Int) -> String {
  String::unsafe_substring(s, start~, end~)
}

///|
fn cu_at(s : String, i : Int) -> Int {
  UInt16::to_int(String::code_unit_at(s, i))
}

///|
fn parse_double_opt(s : String) -> Double? {
  try parse_cli_double(s) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
fn split_commas(s : String) -> Array[String] {
  let out : Array[String] = []
  let n = s.length()
  let mut start = 0
  let mut i = 0
  while i < n {
    if cu_at(s, i) == Char::to_int(',') {
      out.push(substr(s, start, i))
      start = i + 1
    }
    i = i + 1
  }
  out.push(substr(s, start, n))
  out
}

///|
fn is_space_cu(ci : Int) -> Bool {
  ci == Char::to_int(' ') ||
  ci == Char::to_int('\n') ||
  ci == Char::to_int('\t') ||
  ci == Char::to_int('\r')
}

///|
fn split_whitespace(s : String) -> Array[String] {
  let t = s.trim().to_string()
  let out : Array[String] = []
  let n = t.length()
  let mut i = 0
  while i < n {
    while i < n && is_space_cu(cu_at(t, i)) {
      i = i + 1
    }
    if i >= n {
      break
    }
    let start = i
    while i < n && !is_space_cu(cu_at(t, i)) {
      i = i + 1
    }
    out.push(substr(t, start, i))
  }
  out
}

///|
fn expand_double_dash_equals(argv : Array[String]) -> Array[String] {
  argv
  .iter()
  .flat_map(fn(a) {
    // Expand "--name=value" -> ["--name", "value"].
    // clap treats the '=' form as part of the argument name, so we normalize.
    if a.length() >= 4 &&
      cu_at(a, 0) == Char::to_int('-') &&
      cu_at(a, 1) == Char::to_int('-') {
      match String::find(a, "=") {
        Some(eq_idx) =>
          if eq_idx > 2 {
            [substr(a, 0, eq_idx), substr(a, eq_idx + 1, a.length())].iter()
          } else {
            [a].iter()
          }
        None => [a].iter()
      }
    } else {
      [a].iter()
    }
  })
  .collect()
}

///|
fn is_negative_number_token(s : String) -> Bool {
  if s.length() < 2 {
    return false
  }
  if cu_at(s, 0) != Char::to_int('-') {
    return false
  }
  let c1 = cu_at(s, 1)
  // "-1", "-0.1", "-.5", "-1e-3" should count.
  (c1 >= Char::to_int('0') && c1 <= Char::to_int('9')) ||
  c1 == Char::to_int('.')
}

///|
// TheWaWaR/clap treats any token beginning with '-' as an argument name,
// even when we're currently expecting a value.
//
// To allow negative numeric values like "--tx -1", we rewrite "-1" into
// " -1" (leading space). That stops clap from classifying it as a new
// argument, while strconv can still parse it as a number.
fn normalize_negative_number_values(
  argv : Array[String],
  args : Map[String, Arg],
) -> Array[String] {
  let short_to_name : Map[Char, String] = Map::new()
  args.each((name, spec) => match spec.clap.short() {
    Some(ch) => short_to_name.set(ch, name)
    None => ()
  })
  let out : Array[String] = []
  let n = argv.length()
  let mut i = 0
  while i < n {
    let a = argv[i]

    // Long option: --name
    if a.length() >= 3 &&
      cu_at(a, 0) == Char::to_int('-') &&
      cu_at(a, 1) == Char::to_int('-') {
      let name = substr(a, 2, a.length())
      match args.get(name) {
        Some(spec) =>
          match spec.clap.nargs() {
            Some(_) => {
              out.push(a)
              i = i + 1
              while i < n && is_negative_number_token(argv[i]) {
                // Rewrite "-1" -> "−1" so clap doesn't treat it as an option.
                out.push("−" + substr(argv[i], 1, argv[i].length()))
                i = i + 1
              }
            }
            None => {
              out.push(a)
              i = i + 1
            }
          }
        None => {
          out.push(a)
          i = i + 1
        }
      }
      continue
    }

    // Short option: -x
    if a.length() == 2 && cu_at(a, 0) == Char::to_int('-') {
      let ch = a.get_char(1).unwrap()
      match short_to_name.get(ch) {
        Some(name) =>
          match args.get(name) {
            Some(spec) =>
              match spec.clap.nargs() {
                Some(_) => {
                  out.push(a)
                  i = i + 1
                  while i < n && is_negative_number_token(argv[i]) {
                    out.push("−" + substr(argv[i], 1, argv[i].length()))
                    i = i + 1
                  }
                }
                None => {
                  out.push(a)
                  i = i + 1
                }
              }
            None => {
              out.push(a)
              i = i + 1
            }
          }
        None => {
          out.push(a)
          i = i + 1
        }
      }
      continue
    }
    out.push(a)
    i = i + 1
  }
  out
}

///|
pub async fn Args::double(self : Args, name : String) -> Double {
  try {
    let raw : String = @clap.SimpleValue::get_one(self.value, name)
    try parse_cli_double(raw) catch {
      err => {
        eprintln(err.to_string())
        abort("")
        0.0
      }
    } noraise {
      v => v
    }
  } catch {
    err => {
      eprintln(err.to_string())
      abort("")
      0.0
    }
  }
}

///|
pub async fn Args::int(self : Args, name : String) -> Int {
  try {
    let raw : String = @clap.SimpleValue::get_one(self.value, name)
    let s = decode_cli_minus(raw.trim().to_string())
    try @strconv.parse_int(s) catch {
      err => {
        eprintln(err.to_string())
        abort("")
        0
      }
    } noraise {
      v => v
    }
  } catch {
    err => {
      eprintln(err.to_string())
      abort("")
      0
    }
  }
}

///|
pub fn Args::bool_opt(self : Args, name : String) -> Bool {
  match self.value.get_flag(name) {
    Some(v) => v
    None => false
  }
}

///|
pub async fn Args::string_opt(self : Args, name : String) -> String? {
  try @clap.SimpleValue::get_option(self.value, name) catch {
    err => {
      eprintln(err.to_string())
      abort("")
      None
    }
  } noraise {
    v => v
  }
}

///|
// Returns [] if the option wasn't provided.
pub async fn Args::doubles(self : Args, name : String) -> Array[Double] {
  try {
    let raw : Array[String] = @clap.SimpleValue::get_array(self.value, name)
    let out : Array[Double] = []
    for s in raw {
      out.push(parse_cli_double(s)) catch {
        err => {
          eprintln(err.to_string())
          abort("")
          return []
        }
      }
    }
    out
  } catch {
    err => {
      eprintln(err.to_string())
      abort("")
      []
    }
  }
}

///|
// Parse a common translation bundle:
//   -t/--translate <x> <y> <z>
//   --tx <x> --ty <y> --tz <z>
//
// Precedence:
// - If --translate is provided with 3 values, it overrides --tx/--ty/--tz.
// - If --translate is absent, falls back to --tx/--ty/--tz.
//
// Returns None (and prints a friendly error) if --translate is present with
// the wrong number of values.
pub async fn Args::translate_xyz(
  self : Args,
  translate_name? : String = "translate",
  tx_name? : String = "tx",
  ty_name? : String = "ty",
  tz_name? : String = "tz",
) -> (Double, Double, Double)? {
  // Read raw strings first so we can:
  // - support `-t 1,2,3` / `--translate=1,2,3`
  // - distinguish "absent" from "present but invalid"
  let raw : Array[String] = try {
    let v : Array[String] = @clap.SimpleValue::get_array(
      self.value,
      translate_name,
    )
    v
  } catch {
    err => {
      eprintln(err.to_string())
      abort("")
      []
    }
  }
  if raw.length() == 0 {
    return Some(
      (self.double(tx_name), self.double(ty_name), self.double(tz_name)),
    )
  }

  // Standard form: `-t 1 2 3`
  if raw.length() == 3 {
    match
      (
        parse_double_opt(raw[0]),
        parse_double_opt(raw[1]),
        parse_double_opt(raw[2]),
      ) {
      (Some(x), Some(y), Some(z)) => return Some((x, y, z))
      _ => {
        eprintln("error: --translate/-t expects numeric values")
        abort("")
      }
    }
  }

  // Comma-separated form: `-t 1,2,3` or `--translate=1,2,3`
  if raw.length() == 1 {
    let parts = split_commas(raw[0])
    if parts.length() == 3 {
      match
        (
          parse_double_opt(parts[0]),
          parse_double_opt(parts[1]),
          parse_double_opt(parts[2]),
        ) {
        (Some(x), Some(y), Some(z)) => return Some((x, y, z))
        _ => {
          eprintln("error: --translate/-t expects numeric values")
          abort("")
        }
      }
    }

    // Whitespace-separated single-token form: `-t "1 2 3"` or `--translate="1 2 3"`
    let ws_parts = split_whitespace(raw[0])
    if ws_parts.length() == 3 {
      match
        (
          parse_double_opt(ws_parts[0]),
          parse_double_opt(ws_parts[1]),
          parse_double_opt(ws_parts[2]),
        ) {
        (Some(x), Some(y), Some(z)) => return Some((x, y, z))
        _ => {
          eprintln("error: --translate/-t expects numeric values")
          abort("")
        }
      }
    }
  }
  eprintln("error: --translate/-t expects exactly 3 numbers: <x> <y> <z>")
  abort("")
  None
}

///|
// Add the common translation bundle options to an existing args map.
//
// This is intended to keep examples tiny:
//   let args_spec = @cli.with_translate({ "edge": ..., "out": ... })
pub fn with_translate(
  args : Map[String, Arg],
  short_translate? : Char = 't',
  translate_help? : String = "Translate by X Y Z in millimeters (overrides --tx/--ty/--tz)",
  tx_help? : String = "Translate X (mm)",
  ty_help? : String = "Translate Y (mm)",
  tz_help? : String = "Translate Z (mm)",
) -> Map[String, Arg] {
  args.set("translate", opt_vec3(short=short_translate, help=translate_help))
  args.set("tx", opt_double(0.0, help=tx_help))
  args.set("ty", opt_double(0.0, help=ty_help))
  args.set("tz", opt_double(0.0, help=tz_help))
  args
}

///|
pub fn Args::flag(self : Args, name : String) -> Bool {
  match self.value.get_flag(name) {
    Some(v) => v
    None => false
  }
}

///|
pub async fn eprintln(s : String) -> Unit {
  @stdio.stderr.write(s + "\n")
}

///|
// Parse CLI args using clap.
//
// - By default, reads @env.args() and strips argv[0].
// - Returns None if help was printed or parse failed.
pub async fn parse(
  args : Map[String, Arg],
  prog? : String = "PROG",
  description? : String = "",
  cli_args? : Array[String] = [],
  raise_on_error? : Bool = true,
) -> Args? {
  let clap_args : Map[String, @clap.Arg] = Map::new()
  args.each((name, spec) => clap_args.set(name, spec.clap))
  let parser = @clap.Parser::new(prog~, args=clap_args, description~)
  let value = @clap.SimpleValue::new(parser.prog)
  let argv0 : Array[String] = if cli_args.is_empty() {
    @env.args().iter().drop(1).collect()
  } else {
    cli_args
  }
  let argv1 = expand_double_dash_equals(argv0)
  let argv = normalize_negative_number_values(argv1, args)
  try {
    match parser.parse(value, argv) {
      Some(help_message) => {
        println(help_message)
        None
      }
      None => {
        // Validate any opt_double ranges declared via @cli.opt_double(min=..., max=...).
        let mut validation_error : String? = None
        args.each((name, spec) => if validation_error is None {
          if !is_nan(spec.min) || !is_nan(spec.max) {
            let v : Double = try {
              let raw : String = @clap.SimpleValue::get_one(value, name)
              parse_cli_double(raw)
            } catch {
              err => {
                validation_error = Some(err.to_string())
                0.0
              }
            }
            if validation_error is None {
              if !is_nan(spec.min) {
                let min_bad = if spec.min_exclusive {
                  v <= spec.min
                } else {
                  v < spec.min
                }
                if min_bad {
                  let op = if spec.min_exclusive { ">" } else { ">=" }
                  validation_error = Some(
                    "error: --" +
                    name +
                    " must be " +
                    op +
                    " " +
                    spec.min.to_string(),
                  )
                }
              }
              if validation_error is None && !is_nan(spec.max) {
                let max_bad = if spec.max_exclusive {
                  v >= spec.max
                } else {
                  v > spec.max
                }
                if max_bad {
                  let op = if spec.max_exclusive { "<" } else { "<=" }
                  validation_error = Some(
                    "error: --" +
                    name +
                    " must be " +
                    op +
                    " " +
                    spec.max.to_string(),
                  )
                }
              }
            }
          }
        })
        match validation_error {
          Some(msg) => {
            let help = parser.gen_help_message([parser.prog], {})
            if raise_on_error {
              eprintln(msg + "\n" + help)
              abort("")
              None
            } else {
              None
            }
          }
          None => Some(Args::{ value, })
        }
      }
    }
  } catch {
    err => {
      let help = parser.gen_help_message([parser.prog], {})
      if raise_on_error {
        eprintln(err.to_string() + "\n" + help)
        abort("")
        None
      } else {
        None
      }
    }
  }
}
