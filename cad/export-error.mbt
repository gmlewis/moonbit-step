///|
/// ExportError reports why a library export path could not be produced.
///
/// Export helpers raise `ExportError` instead of calling `abort` so callers can
/// recover with `try`/`catch`. Public entry points keep their original aborting
/// behavior for compatibility; the additive `*_checked` entry points raise.
pub suberror ExportError {
  ExportError(String)
}

///|
pub impl Show for ExportError with fn output(self, logger) {
  let ExportError(msg) = self
  logger.write_string("ExportError(" + msg.escape(quote=true) + ")")
}

///|
pub fn ExportError::to_string(self : ExportError) -> String {
  Show::to_string(self)
}
