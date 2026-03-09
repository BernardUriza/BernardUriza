# Register Custom Rule

When the user provides a new rule or guideline for working with this codebase:

1. Extract the rule content from the user's message
2. Determine the appropriate rule file in `.claude/rules/` based on the rule's domain (e.g., `testing.md`, `security.md`, `git.md`)
3. If the rule fits an existing file, append or update it
4. If the rule is entirely new category, create a new file following the naming convention
5. Update the index section in `CLAUDE.md` if a new category is added
6. Never create duplicate rules across files — consolidate related rules in the appropriate location

**Language**: All rules must be written in English, regardless of the input language. 

**File patterns & saving rules**: When creating or updating rule files under `.claude/rules/`, follow the repository's existing conventions:

- Use lowercase, descriptive filenames with a `.md` extension (e.g., `testing.md`, `security.md`).
- Place the file in the `.claude/rules/` directory.
- If updating an existing file, append new content under a clear header and keep the file organized by sections; preserve existing formatting and style.
- If creating a new category, add the new filename and a one-line description to the index section in `CLAUDE.md`.
- Avoid duplicate or overlapping rules: check existing files for related content before adding new rules.
- Keep all rule text in English and match the tone and structure used across other `.claude/rules/*.md` files.

Follow these patterns to maintain consistency across the codebase and make rules discoverable by other contributors.