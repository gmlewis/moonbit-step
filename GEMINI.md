# Gemini CLI Configuration & Instructions

## Model Enforcement

- **Primary Model**: `gemini-3-flash-preview`
- **Strict Adherence**: The Gemini CLI MUST NOT switch models under any circumstances.
- **Fail Over Switching**: If the requested model (`gemini-3-flash-preview`) is unavailable, hitting rate limits, or otherwise unable to process a request, the tool MUST FAIL with an explicit error message instead of falling back to another model (e.g., `gemini-2.5-flash-lite`, `gemini-2.5-flash`, or `gemini-2.5-pro`).
- **Context Integrity**: Model switching has been observed to cause context loss, generation of non-idiomatic or "garbage" code, and breakage of unit tests. To maintain code quality and architectural integrity, only the specified model is permitted.

## Agent Behavior

- Adhere strictly to the principles defined in `AGENTS.md`.
- Prioritize correctness and idiomatic MoonBit over speed.
- If context appears to be lost or if the model's performance degrades, notify the user immediately.
