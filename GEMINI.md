# Gemini CLI Configuration & Instructions

- Please read `AGENTS.md` and `README.md` in the root of this repo to get an
  overview of this repo and general rules.

## Model Enforcement

- **Primary Model**: `gemini-3-flash-preview`
- **Strict Adherence**: The Gemini CLI MUST NOT switch models under any circumstances.
- **Fail Over Switching**: If the requested model (`gemini-3-flash-preview`) is unavailable, hitting rate limits, or otherwise unable to process a request, the tool MUST FAIL with an explicit error message instead of falling back to another model (e.g., `gemini-2.5-flash-lite`, `gemini-2.5-flash`, or `gemini-2.5-pro`).
- **Context Integrity**: Model switching has been observed to cause context loss, generation of non-idiomatic or "garbage" code, and breakage of unit tests. To maintain code quality and architectural integrity, only the specified model is permitted.

## Dependency Management

- **No modification of `.mooncakes`**: The Gemini CLI MUST NOT modify any files within the `.mooncakes` directory. These files are external dependencies and should be treated as read-only.
- **Reporting Dependency Issues**: If a bug is found in a dependency or an improvement is needed, the Gemini CLI should create a new Markdown file (e.g., `DEPENDENCY_FIXES.md`) detailing the specific changes required. The user will then apply these changes in the external repository, publish the update, and re-import the dependency.

## Git Commands

- **NEVER RUN GIT COMMANDS**: The Gemini CLI MUST NOT execute any `git` commands
  with the following exceptions:
  - `git status`
  - `git diff`
  - `git show`
- All version control operations are handled by the user.

## MoonBit Spacing

- **Preserve Spacing**: Within the body of a function, `moon fmt` removes blank
  lines unless they are followed by a blank comment line (`//`).
  When adding spacing for readability, always add a blank line followed
  immediately by a line starting with `//` (and optionally adding text if desired).
  This is not true outside of function bodies, and `moon fmt` insists on having
  a blank line between functions followed by `///|` followed by `/// Docgen-style comment`.

## Running and Testing

- Always use `./run-example.sh` to run specific examples and use `-o /tmp/filename.step`
  to redirect the output to a file (instead of stdout which can be huge).
- Use `./test-all.sh` to run all tests.
- These scripts are safe to use and ensure the environment is correctly set up.

## Agent Behavior

- Adhere strictly to the principles defined in `AGENTS.md`.
- Prioritize correctness and idiomatic MoonBit over speed using a functional-programming
  style when possible, which the author feels is much more readable and easier to understand.
- If context appears to be lost or if the model's performance degrades, notify the user immediately.
- When asked to implement the next example, please put on your "Expert Senior Architect Hat"
  with the goal of creating the example "main.mbt" file to be representative of a
  "beautiful developer experience" for using this MoonBit package. Any helper functions
  that are needed to create the "main.mbt" file should most likely go into the "@cad"
  package (for geometry/topology/modeling helpers) or the "@cli" package for making the
  command-line experience better. In order to create a "beautiful API" for both newbies
  to this package and experienced developers alike, please keep in mind that the imported
  "gmlewis/fonts" dependency (including the @draw) package are owned by the author and
  improvements to those APIs can be recommended and implemented in a separate repo and
  then imported back into this one. Following the "No modification of .mooncakes" rule, any
  improvements or fixes to these external packages must be documented in a separate
  Markdown file for the user to implement externally.
- Make sure to run `./scripts/manage_examples.py 9 --render --readme --validate`
  (for example) to validate the design and update the readme. Also make sure to
  run `./test-all.sh` that runs `moon fmt` and `moon info`.
- Please never use grey in any of the example renders. Use beautiful colors like
  purples, greens, blues, cyans, oranges, magentas, etc.
- As you implement more examples, look for opportunities to make the helper methods
  in the 'cad' package more generally-useful and maybe less highly-specific to a single
  use case. It's OK to have some helper methods in the main.mbt example files if those
  methods are so specific to that example that it doesn't make sense to add them to
  the 'cad' package. We want a nice balance here.
