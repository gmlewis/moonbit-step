///|
/// Standard output destinations shared by every example.
///
/// An example builds its own geometry options, then calls `with_output_args`
/// to add `--out`/`--blend`/`--bpy`/`--gltf` (and optionally `--nostep`).
/// After parsing, `output_paths` collects the values and `write_output`
/// dispatches to the matching exporter.
pub struct OutputPaths {
  step : String?
  blend : String?
  bpy : String?
  gltf : String?
  nostep : Bool
}

///|
/// The exporter selected by an `OutputPaths` value.
pub enum OutputTarget {
  WriteStep
  WriteBlend
  WriteBpy
  WriteGltf
  WriteNothing
}

///|
/// Adds the standard output options to an example's argument spec.
///
/// `blend`/`bpy`/`gltf` can be disabled for examples that do not support
/// them; `nostep` adds the `--nostep` flag.
pub fn with_output_args(
  spec : Map[String, @cli.Arg],
  blend~ : Bool = true,
  bpy~ : Bool = true,
  gltf~ : Bool = true,
  nostep~ : Bool = false,
  out_help~ : String = "Write output to a file (default: stdout)",
  nostep_help~ : String = "Do not write STEP output (neither stdout nor file); useful for pure export/report runs",
) -> Map[String, @cli.Arg] {
  if blend {
    spec.set(
      "blend",
      @cli.opt_string(help="Create Blender 5.0 file (instead of STEP)"),
    )
  }
  if bpy {
    spec.set(
      "bpy",
      @cli.opt_string(
        help="Write Blender 5.0 Python3 script to a file (instead of STEP)",
      ),
    )
  }
  if gltf {
    spec.set(
      "gltf",
      @cli.opt_string(
        help="Write a glTF 2.0 (.gltf) preview file (instead of STEP)",
      ),
    )
  }
  spec.set("out", @cli.opt_string(short='o', help=out_help))
  if nostep {
    spec.set("nostep", @cli.flag(help=nostep_help))
  }
  spec
}

///|
/// Collects the standard output values from parsed arguments.
pub fn output_paths(args : @cli.Args, nostep~ : Bool = false) -> OutputPaths {
  OutputPaths::{
    step: args.string_opt("out"),
    blend: args.string_opt("blend"),
    bpy: args.string_opt("bpy"),
    gltf: args.string_opt("gltf"),
    nostep: nostep || args.bool_opt("nostep"),
  }
}

///|
/// Selects the exporter. Priority: nostep, then blend > bpy > gltf > step.
pub fn select_output(paths : OutputPaths) -> OutputTarget {
  if paths.nostep {
    WriteNothing
  } else if paths.blend is Some(_) {
    WriteBlend
  } else if paths.bpy is Some(_) {
    WriteBpy
  } else if paths.gltf is Some(_) {
    WriteGltf
  } else {
    WriteStep
  }
}

///|
/// Writes `design` to the destination selected by `paths`.
///
/// `blender_segments` and `blender_keep_modifiers` are forwarded to the
/// Blender writers; `checked` is forwarded to the STEP writer.
pub async fn write_output(
  design : @cad.Design,
  paths : OutputPaths,
  blender_segments~ : Int32 = 0,
  blender_keep_modifiers? : Bool,
  checked~ : Bool = false,
) -> Unit {
  match select_output(paths) {
    WriteStep => design.write_step(paths.step, checked~)
    WriteBlend =>
      match paths.blend {
        Some(path) =>
          design.create_blender_file(
            path,
            segments=blender_segments,
            keep_modifiers?=blender_keep_modifiers,
          )
        None => ()
      }
    WriteBpy =>
      design.write_blender_python(
        paths.bpy,
        segments=blender_segments,
        keep_modifiers?=blender_keep_modifiers,
      )
    WriteGltf => design.to_gltf_file(paths.gltf)
    WriteNothing => ()
  }
}
