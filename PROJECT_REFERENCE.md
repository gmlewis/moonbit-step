# moonbit-step — Project Reference (for future Copilot sessions)

Last updated: 2025-12-15

This document is the “single reset point” for working on the MoonBit STEP parser/serializer (`gmlewis/step`).
It summarizes:
- what the codebase currently does,
- where the key entry points are,
- the conventions used for entities and parsing,
- and a pragmatic roadmap toward broad STEP support.

> Note: STEP (ISO 10303) is large. “Full STEP Standard support” is best treated as an iterative program:
> 1) robust ISO-10303-21 (Part 21) file handling, 2) broad entity/value coverage, 3) schema-/AP-aware validation and higher-level semantics.

---

## Quick start

From `moonbit-step/`:
- Run everything: `./test-all.sh`
  - This runs `moon fmt`, `moon info --target native`, and `moon test --target native`.
  - It also runs the same trio for `examples/03-engraved-name-tag/` (a separate `moon.mod.json`).

---

## Current architecture (high level)

### Packages

- Core primitives (root package `gmlewis/step`):
  - `entity.mbt` (the `Entity` trait)
  - `ids.mbt` (`EntityId`, `Ref`)
  - `step_format.mbt` (`step_str`, numeric formatting helpers)
  - `raw_entity.mbt` (`RawEntity`, used to preserve unknown DATA entities)
  - `unknown_entity.mbt` (placeholder type)
- Entities (typed STEP entities):
  - `entities/geometry`
  - `entities/topology`
  - `entities/product`
  - `entities/presentation`
  - `entities/units`
  - `entities/context`
- Parsing: `parse/`
- Repository (entity storage + serialization): `repository/`
- Header section models: `header/`

### Key entry points

- Parse a full STEP file string (HEADER + DATA) into a repository:
  - `parse_repository_from_string(...)` in `parse/parse.mbt`
- Parse from a file:
  - `parse_repository_from_file(...)` in `parse/parse.mbt`

### Repository responsibilities

- Stores parsed entities by id, preserving insertion order.
- Stores parsed header section (`HeaderSection`).
- Serialization:
  - `Repository::to_step_data_section()` → emits only `#<id>=...;` lines.
  - `Repository::to_step_file()` → emits `ISO-10303-21;`, `HEADER;...ENDSEC;`, `DATA;...ENDSEC;`, `END-ISO-10303-21;`.

See:
- `repository/repository.mbt`

---

## ISO-10303-21 (Part 21) file structure supported

### Comments

- STEP block comments of the form `/* ... */` are ignored during parsing (outside of string literals).
- This improves robustness when comments contain semicolons or section keywords.

### HEADER

We model the three most common header entities:
- `FILE_DESCRIPTION((...), '...')`
- `FILE_NAME('...', '...', (...), (...), '...', '...', '...')`
- `FILE_SCHEMA((...))`

Anything else is preserved as `HeaderEntity::Raw(String)`.

Implementation:
- Types + serialization: `header/header.mbt`
- Types + serialization: `header/header.mbt`
- Parsing is implemented inside `parse/parse.mbt`:
  - extracts `HEADER; ... ENDSEC;`
  - tokenizes statements using the same “split on semicolons while respecting parentheses and STEP strings” approach as DATA
  - parses the 3 typed header statements; everything else becomes `Raw`

### DATA

- DATA is tokenized into rows (`RawEntityRow`), then dispatched by entity name.
- Unknown DATA entity names are preserved as `@step.RawEntity` so files can round-trip even when not fully typed.
  - Complex instances are preserved via a dedicated wrapper row name (`__COMPLEX__`).

Implementation:
- `parse/tokenize.mbt` (split statements + parse raw rows)
- `parse/parse.mbt` (dispatch to typed entity parsers)

---

## Conventions for adding a new STEP entity

### 1) Add a typed entity struct + `to_step`

Pattern:
- Define a `pub struct <EntityName> { ... }`.
- Provide `::new(...)` constructor.
- Implement `@step.Entity` for it, with `to_step(self) -> String`.

Important conventions:
- Prefer storing numeric literals as `String` when round-trip formatting matters.
- Use `@step.step_str(...)` to serialize STEP string literals with correct escaping.

Notes on numeric parsing:
- `parse_double(...)` in `parse/parse.mbt` uses `@strconv.parse_double(...)` for correct rounding and stable re-parsing of serialized doubles.

### 2) Add parser function

- Add a `parse_<entity>(args : String) -> <EntityType>` that uses:
  - `split_args(...)` from `parse/tokenize.mbt`
  - helpers like `parse_ref_int`, `parse_double`, etc.

### 3) Wire into Repository

- Add a variant to `AnyEntity` in `repository/repository.mbt`.
- Add `any_entity_<entity>(...)` constructor.
- Add the `entity_to_step` match arm.

### 4) Add dispatch in the DATA parser

- In `parse_repository_from_string`, add a new `else if name == "..." { ... }` branch.

### 5) Add tests

- Unit test `to_step` for the entity in its package.
- Parse test in `parse/parse_test.mbt` if it appears in real files or is a dependency of other entities.

---

## Complex entity instances (multi-inheritance)

Some STEP files use “complex entity instance” form:

```
#187=(
  REPRESENTATION_RELATIONSHIP(...)
  REPRESENTATION_RELATIONSHIP_WITH_TRANSFORMATION(...)
  SHAPE_REPRESENTATION_RELATIONSHIP()
);
```

Current strategy:
- Tokenizer detects `#id=(...)` and marks the row name as `__COMPLEX__`.
- Parser converts this into a `@context.ComplexInstance` whose `parts` are an array of `@context.ComplexPart`.
- Many `ComplexPart`s are typed; any unrecognized ones become `ComplexPart::Raw(name,args)`.

Where:
- Complex instance type/serialization: `entities/context/cx_inst.mbt`
- Complex parsing logic: `parse/parse.mbt` (`parse_complex_instance`)

When extending:
- Prefer adding typed `ComplexPart` variants for frequently occurring complex parts.
- Preserve unknown complex parts as `Raw` to keep round-trip ability.

---

## Current scope vs “full STEP Standard”

### What is already strong

- Robust DATA statement splitting across nested parentheses and STEP string literal escaping.
- Many real-world entities are already implemented (especially geometry/topology/product/presentation needed for KiCad/CAD-ish files).
- Complex instance preservation strategy exists and is progressively being typed.
- Header section support exists and roundtrips.
- Serialization is normalized to LF (CR stripped) so CRLF inputs can roundtrip idempotently.

### Gaps that matter for “full STEP”

Be explicit about the likely work required:

1) **Part 21 grammar completeness**
   - More variations appear in the wild (different whitespace, comments, section ordering, optional sections).
  - Continue expanding coverage for uncommon header/data constructs found in the wild.

2) **Value model completeness**
   - STEP has many inline/select/measure/value patterns.
   - Strategy so far: keep raw strings where necessary; add typed unions where it adds real value.

3) **Schema/AP breadth (AP203/AP214/AP242, etc.)**
   - In practice, entity coverage should be driven by fixtures from real exporters.
   - AP242 is a good general target for CAD interoperability.

4) **Validation and resolution**
   - Reference resolution (ensuring all `#id` refs exist).
   - Optional: higher-level semantics (assemblies, transforms, representation contexts, units).

---

## Recommended roadmap (pragmatic)

### Phase A — Solidify Part 21 file handling

- Preserve unknown DATA entity lines as `@step.RawEntity` so the parser can round-trip *any* file even if not fully typed. (Implemented.)
- Ensure `HEADER` parsing preserves all statements (already does via `Raw`).
- Add fixtures/tests for files with unusual header ordering/content.

Milestone tests:
- `tests/fixtures/ap242-min.step` is a small AP242-flavored Part 21 file used as a stability fixture.
- `tests/fixtures/ap242-stress.step` is a larger AP242-flavored fixture that exercises numeric parsing, complex instances, and unknown entity preservation.
- `tests/fixtures/ap242-comments.step` exercises comment stripping in both HEADER and DATA.
- `tests/fixtures/ap242-strings.step` exercises string literals that contain comment-like sequences and semicolons.
- `tests/ap242_roundtrip_test.mbt` asserts idempotence: parse → `to_step_file()` → parse → `to_step_file()`.
- `tests/ap242_stress_roundtrip_test.mbt` asserts idempotence on the AP242 stress fixture.
- `tests/ap242_comments_roundtrip_test.mbt` asserts idempotence on the AP242 comments fixture.
- `tests/ap242_strings_roundtrip_test.mbt` asserts idempotence on the AP242 strings/comment edgecase fixture.
- `tests/realworld_roundtrip_test.mbt` is a larger real-world roundtrip stress test using `../test-assets/MachineContactMedium.step`.

### Phase B — Systematic entity/value coverage

- Maintain a rolling “next entity” list driven by:
  - `tests/fixtures/` fixtures
  - real exported STEP files in `test-assets/`
- For each new entity:
  - typed model + parser + repo union + tests.

### Phase C — Schema-/context-aware typing (AP242-first)

- Add frequently-encountered context/unit complex instances as typed parts (where it actually helps downstream consumers).
- Model common measure/select patterns as typed unions.

### Phase D — Performance and usability

- Parsing can become O(n) by using maps for id→entity lookup if/when needed.
- Provide higher-level APIs:
  - list entities by type
  - resolve `Ref`s safely
  - optional: compute dependency order / graph utilities

---

## Production-worthiness roadmap (high leverage)

This is a pragmatic checklist for making the MoonBit package “production-worthy” as a reusable library.
The focus is: stable public APIs, predictable failure modes, robustness against real-world STEP/AP242, and regression guardrails.

### 1) Lock down the public API surface

- Decide the official entrypoints and keep them stable and small:
  - `parse_repository_from_string(...)`
  - `parse_repository_from_file(...)`
  - `Repository::to_step_file()`
- Add **non-throwing wrappers** for library consumers (implemented):
  - `parse_repository_from_string_result(...) -> ParseRepositoryResult`
    - `Ok(@repository.Repository)`
    - `Err(StepParseErrorInfo)`
  - `parse_repository_from_file_result(...) -> ParseRepositoryFromFileResult`
    - `Ok(@repository.Repository)`
    - `ParseErr(StepParseErrorInfo)`
    - `IoErr(Error)`

Rationale: downstream users can choose Result-based APIs without adopting `raise` in their own code.

### 2) Make parse errors actionable (line/col + context)

- Keep `StepParseError`, but extend it to carry useful debugging context:
  - byte offset and/or (line, column)
  - current entity id/name (when available)
  - a short statement snippet (bounded length)
- Ensure errors are raised with enough context to triage exporter bugs vs parser limitations.

Status: implemented `StepParseErrorInfo { message, line?, col?, stmt? }` and `format_step_parse_error(...)`.

### 3) Tokenizer “contract” tests

- Add a small suite that asserts *exact* statement boundaries for hard cases:
  - semicolons inside strings
  - doubled quotes inside strings
  - nested parentheses
  - comments (`/* ... */`) in tricky positions (outside strings)

Rationale: most STEP parser regressions start in tokenization.

Status: initial contract tests added in `parse/tokenize_test.mbt` (strings with semicolons, line/col tracking, error payload contains stmt).

Status update: expanded contract coverage for doubled-quote escaping (`''`), nested parentheses, and unterminated-string positioning.

---

## Progress tracker

### 2025-12-13

- Fixed tokenizer refactor fallout and landed position-aware statement spans (`split_statements_with_pos`) and row source positions (`RawEntityRow.line/col`).
- Switched `StepParseError` payload from `String` to structured `StepParseErrorInfo` and updated tests to format errors via `format_step_parse_error`.
- Added non-raising parse entrypoints (`parse_repository_from_string_result`, `parse_repository_from_file_result`) to avoid forcing downstream `raise` usage.
- Added initial tokenizer “contract” tests to pin down tricky string/position behavior.

### 4) Fuzzing + corpus growth

- Maintain a growing fixture corpus (real exporters, especially AP242).
- Add fuzz tests (time-bounded) with invariants:
  - never abort / never hang
  - roundtrip idempotence: parse → `to_step_file()` → parse → `to_step_file()`

Status: implemented a deterministic, time-bounded fuzz smoke suite in `tests/fuzz_smoke_test.mbt`.

### 5) Performance + memory guardrails

- Add benchmarks for:
  - tokenization time
  - parse time
  - serialization time
- Track/limit accidental O(n²) patterns (string concatenation, repeated substring scanning, etc.).

Status: implemented initial `moon bench` guardrails in `tests/bench_parse_test.mbt`.

How to run:

- All benchmarks in the `tests` package:
  - `moon bench --target native -p gmlewis/step/tests`
- Only the benchmarks in the benchmark file:
  - `moon bench --target native -p gmlewis/step/tests -f bench_parse_test.mbt`

Notes:

- Fixture files are loaded once per benchmark (file I/O is not included in the per-iteration timing).
- Serialization benchmarks parse once and only time `Repository::to_step_file()`.

### 6) Versioning + compatibility policy

This project is intended to be used as a library; versioning clarity prevents accidental downstream breakage.

#### SemVer baseline

- We follow SemVer: `MAJOR.MINOR.PATCH`.
- We treat **public API surface** as stable within a major version.
- We treat **behavioral guarantees** below as part of the public contract.

#### Public API surface (stable)

These symbols are considered “public API” and should remain source-compatible within a major version:

- Parsing entrypoints:
  - `parse_repository_from_string(...)`
  - `parse_repository_from_file(...)`
  - `parse_repository_from_string_result(...)`
  - `parse_repository_from_file_result(...)`
- Repository serialization entrypoints:
  - `Repository::to_step_data_section()`
  - `Repository::to_step_file()`
- Parse error payload and formatting helpers:
  - `StepParseErrorInfo` (field names and meaning)
  - `format_step_parse_error(...)`

Everything else is treated as internal implementation detail unless explicitly marked `pub` and referenced above.

#### Compatibility guarantees (stable)

- **No aborts / panics** for malformed inputs. Malformed inputs should fail with `StepParseError` (or `ParseRepositoryResult::Err(...)`).
- **Lossless unknown preservation**: unknown DATA entities and unknown complex parts are preserved so files can round-trip.
- **Deterministic normalization**: serialization is stable and deterministic for a given repository state.
  - Newlines are normalized to `\n`.
  - Comments are not preserved (they’re stripped during parsing).

#### What may change in MINOR versions

- Adding support for new entities, new complex parts, and new header parsing.
- More actionable error messages (message wording, hint text, caret heuristics). Prefer not to break `StepParseErrorInfo` fields.
- More permissive parsing of real-world exporter quirks.

#### What is considered breaking (MAJOR)

- Renaming/removing/changing signatures of the “public API surface” functions listed above.
- Changing the meaning of `StepParseErrorInfo` fields.
- Changing serialization in a way that breaks deterministic round-trips for existing fixtures without a clear bug-fix justification.

#### Parsing posture

- Current stance is **permissive + lossless**:
  - accept real-world whitespace/formatting quirks,
  - preserve unknown constructs as raw for round-trip,
  - normalize output on serialization.
- If we later add a strict mode, it should be an *additional* entrypoint/option, not a behavior change to existing entrypoints.

### 7) CI hardening

- Ensure CI runs:
  - `moon fmt`
  - `moon test --target native`
  - fixture/golden tests that prevent silent serialization changes

Optional (later): add nightly/cron fuzz runs and performance baselines.

---

## Coding / style notes

- MoonBit blocks use `///|` separators.
- Keep filenames short (see `AGENTS.md`).
- Prefer minimal, surgical changes; avoid broad refactors unless necessary.

---

## Testing notes

- Use `inspect(...)` for snapshot-friendly assertions.
- Prefer adding small, targeted parse tests for new grammar/entity forms.

---

## External references

- STEP Tools “STEP standards” overview (helpful for orientation and schema terminology):
  - https://www.steptools.com/stds/step/

Use external references primarily to confirm:
- entity argument ordering and optionality
- which AP/schema a given entity family typically belongs to

---

## “Session reset” checklist (what to do after a break)

1) Run `./test-all.sh` to ensure the workspace is healthy.
2) Skim `PROJECT_REFERENCE.md` (this file) + `AGENTS.md`.
3) Look at `TODO.md` (repo root) and prioritize the next missing entity/value or parser capability.
4) Implement one entity or one parser improvement end-to-end (model → parser → repo union → tests).
