///|
/// # `gmlewis/step`
///
/// A high-level 3D modeling DSL and lossless STEP (ISO 10303-21)
/// parser/serializer in MoonBit.
///
/// The module has two cooperating layers:
///
/// 1. A small **entity core** (this root package) that models STEP entities,
///    assigns them ids, and serializes them to Part 21 text.
/// 2. A fluent **modeling DSL** in `gmlewis/step/cad` that builds models from
///    shapes and compiles them into topologically sound B-Rep solids.
///
/// ## Package map
///
/// | Package | Contents |
/// | --- | --- |
/// | `gmlewis/step` (root) | `Entity` trait, `RawEntity`, `EntityId`, `Ref`, `UnknownEntity`, and STEP text helpers (`step_str`, `fmt_num`). |
/// | `gmlewis/step/cad` | The fluent DSL: `Design`, `SceneNode`, `Shape`, `Profile2D`, `StepContext`, the shape compilers, glTF/Blender/CSG export, and face queries. |
/// | `gmlewis/step/entities/geometry` | Points, directions, vectors, placements, curves, surfaces, blocks, CSG primitives, and boolean results. |
/// | `gmlewis/step/entities/topology` | `MANIFOLD_SOLID_BREP`, closed shells, advanced faces, loops, edges, and vertices. |
/// | `gmlewis/step/entities/product` | Product definitions, shape representations, assemblies, and approvals. |
/// | `gmlewis/step/entities/context` | Geometric representation contexts, units, and uncertainty. |
/// | `gmlewis/step/entities/units` | SI and conversion-based units, derived units, and dimensional exponents. |
/// | `gmlewis/step/entities/presentation` | Colors, fill styles, styled items, presentation layers, and annotations. |
/// | `gmlewis/step/entities/kinematics` | Kinematic joints, links, and pairs. |
/// | `gmlewis/step/entities/tolerancing` | Datums, dimensions, and geometric tolerances. |
/// | `gmlewis/step/header` | The ISO 10303-21 HEADER section. |
/// | `gmlewis/step/repository` | The entity repository, reference allocation, and DATA serialization. |
/// | `gmlewis/step/parse` | Tokenizer and parser for STEP files. |
/// | `gmlewis/step/cli` | CLI helpers used by the examples. |
///
/// ## Entities and lossless round-trips
///
/// Every STEP entity implements `Entity`, whose `to_step` method returns the
/// entity's DATA text:
///
/// ```mbt
/// pub(open) trait Entity {
///   fn to_step(Self) -> String
/// }
/// ```
///
/// `RawEntity` preserves an entity whose type is not modeled yet, so
/// parse → serialize → parse is lossless and idempotent. `EntityId` and `Ref`
/// give entity references a distinct type, so an id cannot be confused with an
/// ordinary integer.
///
/// ## Modeling DSL
///
/// `gmlewis/step/cad` builds a `Design` from `SceneNode`s. Each node pairs a
/// `Shape` with a placement and a color:
///
/// | Shape | Geometry |
/// | --- | --- |
/// | `Cuboid` | Axis-aligned box anchored at the origin. |
/// | `Cylinder` | Right circular cylinder with its base at `Z = 0`. |
/// | `CalibrationChamferBlock` | Box with a chamfer and a filleted edge. |
/// | `ExtrudedProfile` | A `Profile2D` (outer loop plus holes) extruded along `+Z`. |
/// | `ExtrudedBezierProfile` | A Bézier-band profile extruded along `+Z`. |
/// | `SweptProfile` | A profile swept along a path (helix, gear tooth, ...). |
/// | `Union` / `Difference` | Nominal face concatenation of `BooleanUnion` / `BooleanDifference` children (see below). |
///
/// `Design::compile()` turns the scene graph into a `@repository.Repository`;
/// `Design::to_step_file()` returns ISO 10303-21 text. `StepContext` is the
/// per-compilation repository handle: `ctx.direction()`, `ctx.vector()`, and
/// `ctx.cartesian_point()` deduplicate geometry so the output stays compact.
///
/// ## Units and conventions
///
/// - The DSL uses **millimeters** for lengths and **degrees** for rotations.
/// - `fmt_num` writes ISO 10303-21 reals: a mandatory decimal point, an
///   upper-case `E` exponent marker, and trigonometric residue below `1e-12`
///   rounded to `0.0` (which keeps nominally axis-aligned geometry exact).
/// - `step_str` quotes and escapes STEP strings (`'` becomes `''`).
/// - Serializer output is deterministic: parse → serialize → parse is
///   idempotent.
///
/// ## Quick start (modeling)
///
/// ```mbt
/// async fn main {
///   let design = @cad.Design::new(name="my-model")
///     .add(
///       @cad.Cuboid::new(20, 20, 20)
///         .with_name("base")
///         .with_color(@cad.Rgb::orange()),
///     )
///     .add(
///       @cad.CalibrationChamferBlock::new(10, 10, 5, chamfer_size_mm=1.0)
///         .with_name("top-part")
///         .translate(z=20),
///     )
///
///   design.write_step(Some("model.step"))
/// }
/// ```
///
/// ## Quick start (parsing)
///
/// ```mbt
/// fn parse_example(step_text : String) -> Unit {
///   match @parse.parse_repository_from_string_result(step_text) {
///     @parse.ParseRepositoryResult::Ok(repo) => {
///       println("entities=" + repo.len().to_string())
///       println(repo.to_step_file())
///     }
///     @parse.ParseRepositoryResult::Err(info) =>
///       @cli.eprintln(@parse.format_step_parse_error(info))
///   }
/// }
/// ```
///
/// ## Booleans are nominal
///
/// In the STEP backend, `difference()` and `union_all()` concatenate the faces
/// of their children; they do not trim or subtract. The result still describes
/// valid closed shells, but overlapping geometry is not resolved. Use
/// `Design::to_step_file_checked()` (or `write_step(..., checked=true)`) to
/// refuse designs with error diagnostics; a boolean nested inside another
/// boolean contributes no faces and is reported as an error. The Blender
/// backend performs real boolean operations, and
/// `Design::to_csg_step()` emits a real `CSG_SOLID`/`BOOLEAN_RESULT` tree that
/// `scripts/csg_eval.py` can evaluate with OCCT.
///
/// ## Tooling
///
/// ```bash
/// ./scripts/validate_step.py model.step
/// ./scripts/csg_eval.py model-csg.step -o model.step
/// ./scripts/render_step.py model.step preview.png
/// ```
///
/// `render_step.py` renders isometric/top/front/side views with OCCT and
/// composites them into one PNG. `gmlewis/step` itself stays kernel-free; the
/// scripts only need OCCT (`DRAWEXE` or `occt-draw`), and rendering also needs
/// Inkscape.
