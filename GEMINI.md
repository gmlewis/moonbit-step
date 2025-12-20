# Gemini CLI Configuration & Instructions

## Model Enforcement

- **Primary Model**: `gemini-3-flash-preview`
- **Strict Adherence**: The Gemini CLI MUST NOT switch models under any circumstances.
- **Fail Over Switching**: If the requested model (`gemini-3-flash-preview`) is unavailable, hitting rate limits, or otherwise unable to process a request, the tool MUST FAIL with an explicit error message instead of falling back to another model (e.g., `gemini-2.5-flash-lite`, `gemini-2.5-flash`, or `gemini-2.5-pro`).
- **Context Integrity**: Model switching has been observed to cause context loss, generation of non-idiomatic or "garbage" code, and breakage of unit tests. To maintain code quality and architectural integrity, only the specified model is permitted.

## Dependency Management

- **No modification of `.mooncakes`**: The Gemini CLI MUST NOT modify any files within the `.mooncakes` directory. These files are external dependencies and should be treated as read-only.
- **Reporting Dependency Issues**: If a bug is found in a dependency or an improvement is needed, the Gemini CLI should create a new Markdown file (e.g., `DEPENDENCY_FIXES.md`) detailing the specific changes required. The user will then apply these changes in the external repository, publish the update, and re-import the dependency.

## Running and Testing

- Always use `./run-example.sh` to run specific examples and use `-o /tmp/filename.step`
  to redirect the output to a file (instead of stdout which can be huge).
- Use `./test-all.sh` to run all tests.
- These scripts are safe to use and ensure the environment is correctly set up.

## Agent Behavior

- Adhere strictly to the principles defined in `AGENTS.md`.
- Prioritize correctness and idiomatic MoonBit over speed.
- If context appears to be lost or if the model's performance degrades, notify the user immediately.
- When asked to implement the next example, please put on your "Experienced Senior Architect Hat"
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
