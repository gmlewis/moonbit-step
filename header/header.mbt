///|
// Header section models for ISO-10303-21 STEP Part 21 files.
//
// We model the most common/required header entities:
// - FILE_DESCRIPTION
// - FILE_NAME
// - FILE_SCHEMA
//
// Any other header statements can be preserved as raw strings.

///|
pub(all) enum StringOrDollar {
  Dollar
  Str(String)
}

///|
pub(all) enum StringListOrDollar {
  Dollar
  List(Array[String])
}

///|
pub struct FileDescription {
  description : Array[String]
  implementation_level : String
}

///|
pub fn FileDescription::new(
  description : Array[String],
  implementation_level : String,
) -> FileDescription {
  FileDescription::{ description, implementation_level }
}

///|
pub struct FileName {
  name : StringOrDollar
  time_stamp : StringOrDollar
  author : StringListOrDollar
  organization : StringListOrDollar
  preprocessor_version : StringOrDollar
  originating_system : StringOrDollar
  authorization : StringOrDollar
}

///|
pub fn FileName::new(
  name : StringOrDollar,
  time_stamp : StringOrDollar,
  author : StringListOrDollar,
  organization : StringListOrDollar,
  preprocessor_version : StringOrDollar,
  originating_system : StringOrDollar,
  authorization : StringOrDollar,
) -> FileName {
  FileName::{
    name,
    time_stamp,
    author,
    organization,
    preprocessor_version,
    originating_system,
    authorization,
  }
}

///|
pub struct FileSchema {
  schema_identifiers : Array[String]
}

///|
pub fn FileSchema::new(schema_identifiers : Array[String]) -> FileSchema {
  FileSchema::{ schema_identifiers, }
}

///|
pub(all) enum HeaderEntity {
  FileDescription(FileDescription)
  FileName(FileName)
  FileSchema(FileSchema)
  Raw(String)
}

///|
pub struct HeaderSection {
  entities : Array[HeaderEntity]
}

///|
pub fn HeaderSection::empty() -> HeaderSection {
  HeaderSection::{ entities: [] }
}

///|
pub fn HeaderSection::new(entities : Array[HeaderEntity]) -> HeaderSection {
  HeaderSection::{ entities, }
}

///|
fn step_string_or_dollar_to_step(s : StringOrDollar) -> String {
  match s {
    Dollar => "$"
    Str(v) => @step.step_str(v)
  }
}

///|
fn step_string_list_to_step(values : Array[String]) -> String {
  let parts : Array[String] = []
  for i = 0; i < values.length(); i = i + 1 {
    parts.push(@step.step_str(values[i]))
  }
  let joined = parts.join(",")
  "(\{joined})"
}

///|
fn step_string_list_or_dollar_to_step(s : StringListOrDollar) -> String {
  match s {
    Dollar => "$"
    List(values) => step_string_list_to_step(values)
  }
}

///|
fn file_description_to_step(fd : FileDescription) -> String {
  let desc = step_string_list_to_step(fd.description)
  let impl_level = @step.step_str(fd.implementation_level)
  "FILE_DESCRIPTION(\{desc},\{impl_level})"
}

///|
fn file_name_to_step(fn_ : FileName) -> String {
  let a0 = step_string_or_dollar_to_step(fn_.name)
  let a1 = step_string_or_dollar_to_step(fn_.time_stamp)
  let a2 = step_string_list_or_dollar_to_step(fn_.author)
  let a3 = step_string_list_or_dollar_to_step(fn_.organization)
  let a4 = step_string_or_dollar_to_step(fn_.preprocessor_version)
  let a5 = step_string_or_dollar_to_step(fn_.originating_system)
  let a6 = step_string_or_dollar_to_step(fn_.authorization)
  "FILE_NAME(\{a0},\{a1},\{a2},\{a3},\{a4},\{a5},\{a6})"
}

///|
fn file_schema_to_step(fs : FileSchema) -> String {
  let schemas = step_string_list_to_step(fs.schema_identifiers)
  "FILE_SCHEMA(\{schemas})"
}

///|
fn header_entity_to_step(e : HeaderEntity) -> String {
  match e {
    FileDescription(fd) => file_description_to_step(fd)
    FileName(fn_) => file_name_to_step(fn_)
    FileSchema(fs) => file_schema_to_step(fs)
    Raw(s) => s.trim().to_string()
  }
}

///|
// Serialize only the statements inside HEADER...ENDSEC.
// Each statement is terminated with a semicolon and separated by newlines.
pub fn HeaderSection::to_step_statements(self : HeaderSection) -> String {
  let lines : Array[String] = []
  for i = 0; i < self.entities.length(); i = i + 1 {
    lines.push("\{header_entity_to_step(self.entities[i])};")
  }
  lines.join("\n")
}

///|
// Serialize the full HEADER section, including HEADER/ENDSEC wrappers.
pub fn HeaderSection::to_step_header_section(self : HeaderSection) -> String {
  let body = self.to_step_statements()
  if body.length() == 0 {
    "HEADER;\nENDSEC;"
  } else {
    "HEADER;\n\{body}\nENDSEC;"
  }
}
