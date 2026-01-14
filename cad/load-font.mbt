///|
pub using @fonts {type Font}

///|
pub suberror LoaderError {
  LoaderError(String)
} derive(Show, Eq)

///|
/// `load_font` attempts to load a font by its name from the `all-fonts` directory.
/// It first looks in the current directory's `all-fonts/` subdirectory.
/// If not found, it checks the `MOONBIT_FONTS_DIR` environment variable and,
/// `load_font` attempts to load a font by its simple name from the `all-fonts` directory.
/// It expects the font to be in a compressed JSON format (e.g., `font_name.json.gz`),
/// where `font_name` is the short font name (for example, `"baloo"`), not the full
/// package path. For the `baloo` font from package `gmlewis/fonts-b/baloo`, use
/// `load_font("baloo")`. If the font is not found, it raises a `LoaderError` with
/// instructions on how to generate the font.
pub async fn load_font(font_name : String) -> Font raise LoaderError {
  let local_font_path = "all-fonts/\{font_name}.json.gz"
  let env_dir = @sys.get_env_var("MOONBIT_FONTS_DIR")
  let env_font_path = match env_dir {
    Some(dir) =>
      if dir.has_suffix("/") {
        "\{dir}all-fonts/\{font_name}.json.gz"
      } else {
        "\{dir}/all-fonts/\{font_name}.json.gz"
      }
    None => ""
  }
  //
  let mut font_path = local_font_path
  let mut exists = @fs.exists(font_path) catch { _ => false }
  //
  if not(exists) && env_font_path != "" {
    font_path = env_font_path
    exists = @fs.exists(font_path) catch { _ => false }
  }
  //
  if not(exists) {
    let env_msg = if env_font_path != "" {
      env_font_path
    } else {
      "MOONBIT_FONTS_DIR not set"
    }
    let msg =
      $|Font '\{font_name}' not found.
      #|Checked paths:
      $|- \{local_font_path}
      $|- \{env_msg}
      #|
      #|To generate this font, follow these steps:
      #|1. Navigate to the 'gmlewis/fonts' repo directory.
      $|2. Ensure you have the 'all-fonts.txt' file containing '\{font_name}'.
      #|3. Run the generation script:
      $|   python3 scripts/compress-all-fonts.py --force --font \{font_name}
      #|4. Rerun your program.
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
    @json.JsonDecodeError(e) => raise LoaderError("JSON decode error: \{e}")
    e => raise LoaderError("Unexpected error loading font: \{e}")
  }
}
