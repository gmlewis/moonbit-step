///|
// Tiny convenience wrapper around moonbitlang/core/argparse.
//
// Goals:
// - Examples don't need to pass @env.args() around.
// - Examples don't need to remember to strip argv[0].
// - Keep the full power of @argparse available when needed.

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
// NUL sentinel meaning "no short option".
let no_short : Char = Int32::unsafe_to_char(0)

///|
// Argument specification wrapper.
//
// This lets @cli validate numeric ranges (min/max) without requiring callers
// to write manual checks.
pub struct Arg {
  priv short : Char // U+0000 = no short option
  priv help : String
  priv kind : ArgKind
  priv default : String? // Some for opt_int/opt_double, None otherwise
  priv min : Double
  priv max : Double
  priv min_exclusive : Bool
  priv max_exclusive : Bool
}

///|
enum ArgKind {
  Value // single-value option (int / double / string)
  Vec3 // 0-or-3-values option (translate)
  Flag
}

///|
pub fn opt_int(
  default : Int32,
  short~ : Char = no_short,
  help~ : String = "",
  min? : Int32,
  max? : Int32,
) -> Arg {
  let min = match min {
    Some(v) => v.to_double()
    None => nan()
  }
  let max = match max {
    Some(v) => v.to_double()
    None => nan()
  }
  Arg::{
    short,
    help,
    kind: Value,
    default: Some(default.to_string()),
    min,
    max,
    min_exclusive: false,
    max_exclusive: false,
  }
}

///|
pub fn opt_double(
  default : Double,
  short~ : Char = no_short,
  help~ : String = "",
  min~ : Double = nan(),
  max~ : Double = nan(),
  min_exclusive~ : Bool = false,
  max_exclusive~ : Bool = false,
) -> Arg {
  Arg::{
    short,
    help,
    kind: Value,
    default: Some(default.to_string()),
    min,
    max,
    min_exclusive,
    max_exclusive,
  }
}

///|
pub fn opt_string(short~ : Char = no_short, help~ : String = "") -> Arg {
  Arg::{
    short,
    help,
    kind: Value,
    default: None,
    min: nan(),
    max: nan(),
    min_exclusive: false,
    max_exclusive: false,
  }
}

///|
pub fn flag(short~ : Char = no_short, help~ : String = "") -> Arg {
  Arg::{
    short,
    help,
    kind: Flag,
    default: None,
    min: nan(),
    max: nan(),
    min_exclusive: false,
    max_exclusive: false,
  }
}

///|
// Convenience for `--name <x> <y> <z>`.
//
// The multi-token form (`-t 1 2 3`) is folded into a single comma-joined
// value by preprocess_argv before parsing; `-t 1,2,3` and `-t "1 2 3"` work
// natively.
pub fn opt_vec3(short~ : Char = no_short, help~ : String = "") -> Arg {
  Arg::{
    short,
    help,
    kind: Vec3,
    default: None,
    min: nan(),
    max: nan(),
    min_exclusive: false,
    max_exclusive: false,
  }
}

///|
// Parsed values wrapper.
pub struct Args {
  priv matches : @argparse.Matches
  priv prog : String
  priv argv : Array[String]
  priv specs : Map[String, Arg]
}

///|
fn substr(s : String, start : Int32, end : Int32) -> String {
  String::unsafe_substring(s, start~, end~)
}

///|
fn cu_at(s : String, i : Int32) -> Int32 {
  UInt16::to_int(String::code_unit_at(s, i))
}

///|
fn parse_cli_double(s : String) -> Double raise {
  @string.parse_double(s.trim().to_owned())
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
fn is_space_cu(ci : Int32) -> Bool {
  ci == Char::to_int(' ') ||
  ci == Char::to_int('\n') ||
  ci == Char::to_int('\t') ||
  ci == Char::to_int('\r')
}

///|
fn split_whitespace(s : String) -> Array[String] {
  let t = s.trim().to_owned()
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
fn is_negative_number_token(s : String) -> Bool {
  if s.length() < 2 {
    return false
  }
  if cu_at(s, 0) != Char::to_int('-') {
    return false
  }
  let c1 = cu_at(s, 1)
  // "-1", "-0.1", "-.5", "-1e-3", "-1,2,3" should count.
  (c1 >= Char::to_int('0') && c1 <= Char::to_int('9')) ||
  c1 == Char::to_int('.')
}

///|
// A token that would be treated as an option/terminator rather than a value.
// Negative numbers ("-1", "-.5", "-1e-3") and bare "-" are value-like.
fn option_like(t : String) -> Bool {
  t.has_prefix("-") && t != "-" && !is_negative_number_token(t)
}

///|
// Match an option-like token to a spec: returns (name, spec, has_inline_value).
// Handles "--name", "--name=value", "-x", "-xvalue", "-x=value".
fn spec_for_token(t : String, args : Map[String, Arg]) -> (String, Arg, Bool)? {
  if t.has_prefix("--") && t.length() > 2 {
    let eq_idx : Int32? = String::find(t, "=")
    let name = match eq_idx {
      Some(idx) if idx > 2 => substr(t, 2, idx)
      _ => substr(t, 2, t.length())
    }
    match args.get(name) {
      Some(spec) => Some((name, spec, eq_idx is Some(_)))
      None => None
    }
  } else if t.length() >= 2 &&
    cu_at(t, 0) == Char::to_int('-') &&
    !is_negative_number_token(t) {
    let ch = t.get_char(1).unwrap()
    let mut found : (String, Arg)? = None
    args.each((name, spec) => {
      if found is None && spec.short == ch {
        found = Some((name, spec))
      }
    })
    match found {
      Some((name, spec)) => Some((name, spec, t.length() > 2))
      None => None
    }
  } else {
    None
  }
}

///|
// Preprocess argv to replicate old value-collection semantics that @argparse
// cannot express:
// 1. Vec3 merge: an option like `-t` takes 0 or 3 values, but @argparse
//    options take exactly one value per occurrence, so `-t 1 2 3` is folded
//    into `-t 1,2,3` before parsing.
// 2. Bare option drop: value-taking options are declared with
//    allow_hyphen_values, so a pending option would swallow ANY following
//    token (e.g. `--tx --ty 2` would set tx="--ty"). Old behavior collected
//    0 values and applied the default (int/double) or treated the option as
//    absent (string/vec3), so a bare option is dropped instead.
fn preprocess_argv(
  argv : Array[String],
  args : Map[String, Arg],
) -> Array[String] {
  let out : Array[String] = []
  let n = argv.length()
  let mut i = 0
  while i < n {
    let t = argv[i]
    if t == "--" {
      // Terminator: copy verbatim; the parser treats the rest as positionals.
      while i < n {
        out.push(argv[i])
        i = i + 1
      }
      break
    }
    if option_like(t) {
      match spec_for_token(t, args) {
        Some((_, spec, inline)) =>
          if spec.kind is Flag {
            out.push(t)
            i = i + 1
          } else if inline {
            out.push(t)
            i = i + 1
          } else if spec.kind is Vec3 {
            let vals : Array[String] = []
            let mut j = i + 1
            while j < n && vals.length() < 3 && !option_like(argv[j]) {
              vals.push(argv[j])
              j = j + 1
            }
            if vals.is_empty() {
              // Bare vec3 option: treated as absent, so translate_xyz
              // falls back to --tx/--ty/--tz.
              i = j
            } else {
              out.push(t)
              out.push(vals.join(","))
              i = j
            }
          } else if i + 1 < n && !option_like(argv[i + 1]) {
            out.push(t)
            out.push(argv[i + 1])
            i = i + 2
          } else {
            // Bare single-value option: drop the token so @argparse never
            // sees a pending option with no value.
            i = i + 1
          }
        None => {
          out.push(t)
          i = i + 1
        }
      }
    } else {
      out.push(t)
      i = i + 1
    }
  }
  out
}

///|
// @argparse raises a build error (panic) for duplicate short options, while
// the old parser silently kept the last one. Catch conflicts up front.
async fn check_duplicate_shorts(args : Map[String, Arg]) -> Unit {
  let seen : Map[Char, String] = Map([])
  let mut dup : (Char, String, String)? = None
  args.each((name, spec) => {
    if spec.short != no_short {
      match seen.get(spec.short) {
        Some(first) => if dup is None { dup = Some((spec.short, first, name)) }
        None => seen.set(spec.short, name)
      }
    }
  })
  match dup {
    Some((ch, first, second)) => {
      eprintln(
        "error: duplicate short option '-\{ch}' used by --\{first} and --\{second}",
      )
      abort("")
    }
    None => ()
  }
}

///|
pub async fn Args::double(self : Args, name : String) -> Double {
  let raw : String = match self.matches.values.get(name) {
    Some(vals) if vals.length() >= 1 => vals[0]
    _ => {
      eprintln("error: value not found for: \{name}")
      abort("")
      ""
    }
  }
  try parse_cli_double(raw) catch {
    err => {
      eprintln(err.to_string())
      abort("")
      0.0
    }
  } noraise {
    v => v
  }
}

///|
pub async fn Args::int(self : Args, name : String) -> Int32 {
  let raw : String = match self.matches.values.get(name) {
    Some(vals) if vals.length() >= 1 => vals[0]
    _ => {
      eprintln("error: value not found for: \{name}")
      abort("")
      ""
    }
  }
  try @string.parse_int(raw.trim().to_owned()) catch {
    err => {
      eprintln(err.to_string())
      abort("")
      0
    }
  } noraise {
    v => v
  }
}

///|
pub fn Args::bool_opt(self : Args, name : String) -> Bool {
  self.matches.flags.get(name).unwrap_or(false)
}

///|
pub fn Args::string_opt(self : Args, name : String) -> String? {
  match self.matches.values.get(name) {
    Some(vals) if vals.length() == 1 => Some(vals[0])
    _ => None
  }
}

///|
// Returns [] if the option wasn't provided.
pub async fn Args::doubles(self : Args, name : String) -> Array[Double] {
  let raw : Array[String] = self.matches.values.get(name).unwrap_or([])
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
  translate_name~ : String = "translate",
  tx_name~ : String = "tx",
  ty_name~ : String = "ty",
  tz_name~ : String = "tz",
) -> (Double, Double, Double)? {
  // Read raw strings first so we can:
  // - support `-t 1,2,3` / `--translate=1,2,3`
  // - distinguish "absent" from "present but invalid"
  let raw : Array[String] = self.matches.values
    .get(translate_name)
    .unwrap_or([])
  if raw.length() == 0 {
    return Some(
      (self.double(tx_name), self.double(ty_name), self.double(tz_name)),
    )
  }

  // Comma-separated form: `-t 1,2,3` or `--translate=1,2,3` (also the
  // multi-token form `-t 1 2 3` after preprocess_argv merges it).
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

  // Legacy form: three separately-collected values.
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
  short_translate~ : Char = 't',
  translate_help~ : String = "Translate by X Y Z in millimeters (overrides --tx/--ty/--tz)",
  tx_help~ : String = "Translate X (mm)",
  ty_help~ : String = "Translate Y (mm)",
  tz_help~ : String = "Translate Z (mm)",
) -> Map[String, Arg] {
  args.set("translate", opt_vec3(short=short_translate, help=translate_help))
  args.set("tx", opt_double(0.0, help=tx_help))
  args.set("ty", opt_double(0.0, help=ty_help))
  args.set("tz", opt_double(0.0, help=tz_help))
  args
}

///|
pub fn Args::flag(self : Args, name : String) -> Bool {
  self.matches.flags.get(name).unwrap_or(false)
}

///|
/// Repository URL advertised in generated files.
let step_repo_url : String = "https://github.com/gmlewis/moonbit-step"

///|
fn shell_quote(s : String) -> String {
  let has_space = match String::find(s, " ") {
    Some(_) => true
    None => false
  }
  let has_tab = match String::find(s, "\t") {
    Some(_) => true
    None => false
  }
  let has_quote = match String::find(s, "'") {
    Some(_) => true
    None => false
  }
  if has_space || has_tab || has_quote {
    "'" + s.replace(old="'", new="'\\''") + "'"
  } else {
    s
  }
}

///|
/// example_number reduces an example program name to the number used by
/// `./run-example.sh`, e.g. "38-planetary-gearbox" -> "38".
fn example_number(prog : String) -> String {
  match String::find(prog, "-") {
    Some(idx) if idx > 0 => substr(prog, 0, idx)
    _ => prog
  }
}

///|
/// lex_compare compares two strings lexicographically. (MoonBit's
/// `String::compare` compares length first, which does not sort names
/// alphabetically.)
fn lex_compare(a : String, b : String) -> Int32 {
  let la = a.length()
  let lb = b.length()
  let n = if la < lb { la } else { lb }
  for i in 0..<n {
    let ca = UInt16::to_int(String::code_unit_at(a, i))
    let cb = UInt16::to_int(String::code_unit_at(b, i))
    if ca < cb {
      return -1
    }
    if ca > cb {
      return 1
    }
  }
  if la < lb {
    -1
  } else if la > lb {
    1
  } else {
    0
  }
}

///|
/// sorted_strings returns a new array sorted in ascending order.
fn sorted_strings(xs : Array[String]) -> Array[String] {
  let out = xs.copy()
  let n = out.length()
  for i in 1..<n {
    let v = out[i]
    let mut j = i - 1
    while j >= 0 && lex_compare(out[j], v) > 0 {
      out[j + 1] = out[j]
      j = j - 1
    }
    out[j + 1] = v
  }
  out
}

///|
/// command_line returns the documented invocation for this run, e.g.
/// `./run-example.sh 38 --numTeeth 12 -o gearbox.step`.
pub fn Args::command_line(self : Args) -> String {
  let parts : Array[String] = ["./run-example.sh", example_number(self.prog)]
  for a in self.argv {
    parts.push(shell_quote(a))
  }
  parts.join(" ")
}

///|
/// documentation returns a self-documenting block with the repository URL,
/// the exact command line used, and every declared parameter value (including
/// defaults). Pass it to `@cad.Design::new(documentation=...)` so generated
/// STEP files explain how to reproduce them.
pub fn Args::documentation(self : Args) -> String {
  let lines : Array[String] = [
    "Generated by the gmlewis/step MoonBit CAD library.",
    "Repository: " + step_repo_url,
    "Example:    " + self.prog,
    "Command:    " + self.command_line(),
    "Parameters:",
  ]
  let names : Array[String] = []
  self.specs.each(fn(name, _spec) { names.push(name) })
  for name in sorted_strings(names) {
    let value = match self.specs.get(name) {
      Some(spec) =>
        if spec.kind is Flag {
          self.matches.flags.get(name).unwrap_or(false).to_string()
        } else {
          match self.matches.values.get(name) {
            Some(vals) => vals.join(",")
            None => "(unset)"
          }
        }
      None => "(unknown)"
    }
    lines.push("  --" + name + " = " + value)
  }
  lines.join("\n")
}

///|
pub async fn eprintln(s : String) -> Unit {
  @stdio.stderr.write(s + "\n")
}

///|
/// `die` reports a fatal CLI error and exits with a non-zero status.
///
/// It uses the synchronous `eprintln` from `moonbitlang/core/builtin`, so it
/// also works from synchronous helpers and closures where the async
/// `@cli.eprintln` cannot be called. This is the synchronous spelling of the
/// `@cli.eprintln(msg)` + `abort("")` pattern required by AGENTS.md.
pub fn[T] die(msg : String) -> T {
  @builtin.eprintln(msg)
  abort("")
}

///|
// Parse CLI args using @argparse.
//
// - By default, reads @env.args() and strips argv[0].
// - Returns None if help was printed or parse failed.
pub async fn parse(
  args : Map[String, Arg],
  prog~ : String = "PROG",
  description~ : String = "",
  cli_args~ : Array[String] = [],
  raise_on_error~ : Bool = true,
) -> Args? {
  check_duplicate_shorts(args)
  let argv0 : Array[String] = if cli_args.is_empty() {
    @env.args().iter().drop(1).collect()
  } else {
    cli_args
  }
  let argv = preprocess_argv(argv0, args)
  let flags : Array[@argparse.FlagArg] = []
  let options : Array[@argparse.OptionArg] = []
  args.each((name, spec) => {
    let default_values : Array[String] = match spec.default {
      Some(d) => [d]
      None => []
    }
    if spec.short == no_short {
      if spec.kind is Flag {
        flags.push(@argparse.FlagArg(name[:], about=spec.help[:]))
      } else {
        options.push(
          @argparse.OptionArg(
            name[:],
            about=spec.help[:],
            default_values=default_values[:],
            allow_hyphen_values=true,
          ),
        )
      }
    } else if spec.kind is Flag {
      flags.push(
        @argparse.FlagArg(name[:], short=spec.short, about=spec.help[:]),
      )
    } else {
      options.push(
        @argparse.OptionArg(
          name[:],
          short=spec.short,
          about=spec.help[:],
          default_values=default_values[:],
          allow_hyphen_values=true,
        ),
      )
    }
  })
  let cmd = @argparse.Command(
    prog[:],
    flags=flags[:],
    options=options[:],
    about=description[:],
  )
  let matches : @argparse.Matches = cmd.parse(argv=argv[:]) catch {
    err => {
      // The error text already contains the message plus the full contextual
      // help. On --help/-h, @argparse prints and exits 0 internally.
      if raise_on_error {
        eprintln(err.to_string())
        abort("")
      }
      return None
    }
  }
  // Validate any opt_double/opt_int ranges declared via @cli.opt_double(min=..., max=...).
  let mut validation_error : String? = None
  args.each((name, spec) => {
    if validation_error is None {
      if !is_nan(spec.min) || !is_nan(spec.max) {
        let v : Double = match matches.values.get(name) {
          Some(vals) if vals.length() >= 1 =>
            parse_cli_double(vals[0]) catch {
              err => {
                validation_error = Some(err.to_string())
                0.0
              }
            }
          _ => {
            validation_error = Some("error: value not found for: \{name}")
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
    }
  })
  match validation_error {
    Some(msg) =>
      if raise_on_error {
        eprintln(msg + "\n" + cmd.render_help())
        abort("")
        None
      } else {
        None
      }
    None => Some(Args::{ matches, prog, argv: argv0, specs: args, })
  }
}
