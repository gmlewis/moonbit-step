///|
pub using @fonts {type Font}

///|
pub suberror LoaderError {
  LoaderError(String)
} derive(Eq)

///|
pub impl Show for LoaderError with fn output(self, logger) {
  let LoaderError(msg) = self
  logger.write_string(
    (
      $|LoaderError(\{msg.escape(quote=true)})
    ),
  )
}

///|
/// `load_font` loads a font by its simple name in the compressed JSON format
/// produced by `gmlewis/fonts` (for example, `baloo.json.gz`).
///
/// `font_name` is the short font name (for example, `"baloo"`), not the full
/// package path. For the `baloo` font from package `gmlewis/fonts-b/baloo`,
/// use `load_font("baloo")`. The examples' `baloo` font is vendored in
/// `assets/fonts/`, so a normal checkout needs no environment variable.
///
/// Paths are checked in this order:
///
/// 1. `./assets/fonts/{font_name}.json.gz`
/// 2. `./all-fonts/{font_name}.json.gz` (legacy working-directory layout)
/// 3. `$MOONBIT_STEP_ROOT/assets/fonts/{font_name}.json.gz`
/// 4. `$MOONBIT_FONTS_DIR/all-fonts/{font_name}.json.gz`
///
/// If the font is not found, it raises a `LoaderError` listing every path that
/// was checked, along with instructions on how to generate the font.
pub async fn load_font(font_name : String) -> Font raise LoaderError {
  let file_name = "\{font_name}.json.gz"
  let candidates : Array[String] = [
    "./assets/fonts/\{file_name}",
    "./all-fonts/\{file_name}",
  ]
  if @env.get_env_var("MOONBIT_STEP_ROOT") is Some(root) {
    let dir = if root.has_suffix("/") { root } else { "\{root}/" }
    candidates.push("\{dir}assets/fonts/\{file_name}")
  }
  let env_dir = @env.get_env_var("MOONBIT_FONTS_DIR")
  if env_dir is Some(dir) {
    let base = if dir.has_suffix("/") { dir } else { "\{dir}/" }
    candidates.push("\{base}all-fonts/\{file_name}")
  }
  //
  let mut font_path : String? = None
  for path in candidates {
    if font_path is None {
      let exists = @fs.exists(path) catch { _ => false }
      if exists {
        font_path = Some(path)
      }
    }
  }
  //
  guard font_path is Some(font_path) else {
    let checked_paths = candidates.map(fn(path) { "- \{path}" }).join("\n")
    let msg =
      $|Font '\{font_name}' not found.
      $|Checked paths:
      $|\{checked_paths}
      $|
      $|To generate this font, follow these steps:
      $|1. Navigate to the 'gmlewis/fonts' repo directory.
      $|2. Ensure you have the 'all-fonts.txt' file containing '\{font_name}'.
      $|3. Run the generation script:
      $|   python3 scripts/compress-all-fonts.py --force --font \{font_name}
      $|4. Copy 'all-fonts/\{file_name}' to 'assets/fonts/\{file_name}' or set
      $|   MOONBIT_FONTS_DIR to the fonts repo, then rerun your program.
    try! @stdio.stderr.write(msg + "\n")
    raise LoaderError(
      "Font '\{font_name}' not found. See above for instructions.",
    )
  }
  //
  try {
    let data = @fs.read_file(font_path) catch {
      e => raise LoaderError("Error reading font file at '\{font_path}': \{e}")
    }
    //
    let bytes = data.binary()
    let buffer = @io.Buffer::from_bytes(bytes)
    //
    // Decompress the gzip data
    let (gzip_reader, err) = @gzip.Reader::new(buffer)
    match err {
      Some(e) => raise LoaderError("Gzip decompression error: \{e}")
      None => ()
    }
    //
    let (json_bytes, err) = @io.read_all(gzip_reader)
    match err {
      Some(e) => raise LoaderError("Read error during decompression: \{e}")
      None => ()
    }
    //
    let json_str = @base64.bytes2str(json_bytes.to_bytes())
    let json = @json.parse(json_str)
    let font : Font = @json.from_json(json)
    font
  } catch {
    @json.JsonDecodeError(e) =>
      raise LoaderError("JSON decode error: \{Repr(e)}")
    e => raise LoaderError("Unexpected error loading font: \{Repr(e)}")
  }
}
