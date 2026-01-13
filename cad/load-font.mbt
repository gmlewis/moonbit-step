///|
/// `load_font` attempts to load a font by its name from the `all-fonts` directory of the "gmlewis/fonts" repo.
/// It first looks in the `all-fonts/` subdirectory of the running executable (which will likely not exist).
/// If not found, it checks the `MOONBIT_FONTS_DIR` environment variable and,
/// `load_font` attempts to load a font by its simple name from the `all-fonts` directory of *that* directory.
/// It expects the font to be in a compressed JSON format (e.g., `font_name.json.gz`),
/// where `font_name` is the short font name (for example, `"baloo"`), not the full
/// package path. For the `baloo` font from package `gmlewis/fonts-b/baloo`, use
/// `load_font("baloo")`. If the font is not found, it raises a `LoaderError` with
/// instructions on how to generate the font.
pub async fn load_font(name : String) -> @fonts.Font {
  @loader.load_font(name)
}
