---
name: change-cleanup
description: >
  Clean up and harden code introduced by the current branch without drifting into broad refactors. Use when Codex should review branch-local changes against a base branch, improve newly added or modified code for reuse, clarity, docs, specs, and dead-state cleanup, and optionally work interactively with the user in `self-driving`, `smart`, or `assisted` mode. This skill is for targeted cleanup after feature iteration, especially when Elixir, Phoenix LiveView, or React changes may have left duplicated helpers, missing docs/specs, stale assigns/props/attrs, or overlapping state.
---

## Purpose

Use this skill to clean up the code introduced or changed by the current branch while keeping scope tight and evidence-based.

The primary goal is to improve the quality of the branch's changes, not to perform opportunistic repo-wide cleanup. Focus first on files added or modified in the branch, then expand only when a small supporting refactor outside the diff is necessary to remove duplication or extract a shared helper.

## Scope Rules

1. Ask which mode to use only when the user did not already provide one.
   - If the user already specified `self-driving`, `smart`, or `assisted`, confirm that mode and proceed.
   - If the mode is still unknown, in that first response briefly explain what each mode means.
   - Present the modes as a numbered list in this order so the user can reply with just the number:
     1. `self-driving`
     2. `smart`
     3. `assisted`

2. State the base branch before doing cleanup work.
   - Default to `master` unless the user says otherwise.
   - Make the chosen base explicit so the user can correct it.

3. Use the branch diff against the base branch as the primary cleanup boundary.

4. Within an existing file, only apply cleanup to newly added or modified code units.
   - Do not add docs, specs, or comments to unchanged functions just because the module changed.
   - Do not add `@doc` to unchanged public functions.
   - Do not add comments to unchanged private helpers.
   - If a changed function needs broader internal reshaping to make the new logic clean, refactor that full function as needed.

5. Allow touching files outside the diff only when that is the smallest sound change needed to:
   - extract a shared helper
   - consolidate duplicated logic
   - move a changed function into a more appropriate module

6. Do not perform speculative cleanup on unrelated untouched code.
   - If something is ugly but outside the changed surface, leave it alone.
   - Exception: if a changed function must be reorganized so the modified behavior remains understandable and maintainable, clean up that function.

## Cleanup Targets

Evaluate the changed surface for the following:

1. Helper overgrowth and duplication
   - Detect repeated helper patterns, especially repeated `defp` helpers across modules.
   - Before creating a new helper, search for an existing one in the same function, same module, and nearby domain modules.
   - If a helper should be shared, prefer extracting or reusing a common implementation instead of copying the same pattern again.

2. Missing or outdated specs
   - Add or update `@spec` for new or modified functions where the language conventions support it.
   - Prefer `@spec` for:
     - new or modified public functions
     - callbacks and behaviour implementations
     - shared functions called across modules
     - logic with non-obvious inputs or return shapes
   - Consider `@spec` for private functions only when the logic is complex enough that the type
     contract materially improves readability or static analysis.
   - Do not add low-value specs that only restate obvious contracts such as generic `map()`,
     `list()`, or trivial wrappers without improving documentation or Dialyzer coverage.
   - For Phoenix function components, prefer `attr` declarations as the primary interface contract.
     Add `@spec` only when the component has non-trivial options or when surrounding helper
     functions expose a meaningful contract.
   - Before using `Module.t()` in a spec, verify that the referenced module actually defines
     `@type t()` or `@opaque t()`.
   - If the module does not export `t()`, use the correct structural type instead, such as
     `%Module{}` or another explicit type that the module really exposes.

3. Missing or outdated public function docs
   - Add or update `@doc` for new or modified public functions.
   - Keep the documentation concise and behavior-focused.

4. Missing or outdated module docs
   - New modules should have at least a minimal `@moduledoc`.
   - When a function is added or changed in an existing module, review the current `@moduledoc`.
   - Update it when the changed surface alters the module's responsibility, scope, or public surface.
   - If the changed function no longer matches the module's stated purpose, evaluate moving it to a more appropriate module.

5. Inline explanation for complex logic
   - Add a short inline comment when new or modified logic is hard to understand without business context.
   - Use comments to explain intent, constraints, or domain logic.
   - Do not add comments that restate obvious code.
   - Do not mention ticket IDs, people, chat history, or temporary implementation history.

6. Stale assigns, props, attrs, and other iteration residue
   - Check for unused LiveView assigns, function component attrs, React props, and similar state or interface residue introduced during iteration.
   - Remove them only after confirming they are truly unused.
   - Prefer reusing already-available state rather than introducing overlapping derived state.

7. Overlapping state
   - Detect newly introduced assigns or props that duplicate information already available elsewhere.
   - Prefer computing simple derivations from existing state when that is cheaper and clearer than maintaining parallel state.

8. Duplicate functions or near-duplicate behavior
   - Search beyond the current edit loop when needed.
   - Confirm duplication with codebase facts before proposing consolidation.

## Workflow

1. Determine the mode before starting the cleanup pass.
   - If the user already provided `self-driving`, `smart`, or `assisted`, confirm that mode and proceed without asking again.
   - Otherwise, in the first reply include:
     - the explicit base branch, defaulting to `master` unless already provided
     - one short sentence explaining the cleanup frame
     - a numbered list:
       1. `self-driving`: fully automatic cleanup pass; research, decide, and implement without per-finding approval
       2. `smart`: inspect first, summarize findings, review them interactively, then wait for approval before editing
       3. `assisted`: walk rule-by-rule with the user before any edits, then wait for approval before editing
   - If the mode was not already provided, end by asking the user to reply with `1`, `2`, or `3`.

2. Confirm the cleanup frame.
   - State the base branch.
   - State that the cleanup scope starts from the diff against that base.
   - Note that supporting refactors outside the diff may still be considered when needed for reuse or deduplication.

3. Build context from facts.
   - Inspect the diff against the base branch.
   - Read the changed code.
   - Search nearby modules or components when checking for duplication, helper reuse, or better module placement.
   - Do not guess about usage, duplication, or business intent.

4. Classify findings before proposing edits.
   For each finding, record:
   - the rule it maps to
   - the affected code unit
   - whether it is definitely actionable, needs user input, or should be left alone
   - whether it requires touching a file outside the diff

## Mode Behavior

### `self-driving`

Use this mode for a fully automatic cleanup pass.

1. Research the changed surface.
2. Decide what to improve using the rules in this skill.
3. Implement the cleanup without waiting for per-finding approval.
4. Keep the changes tightly scoped to the branch's changed behavior plus any necessary supporting deduplication refactors.
5. Summarize what changed, what was intentionally left alone, and any remaining risks.

### `smart`

Use this mode for one review pass before editing.

1. Research all cleanup targets first.
2. Produce a concise initial summary before editing anything.

   The summary must include:
   - total findings
   - count by cleanup category
   - which findings require touching files outside the diff
   - a short high-level situation summary
   - a clear statement that implementation has not started yet

3. Review findings interactively, one by one.
   For each finding, present:
   - `Finding`
   - `Rule`
   - `Context`
   - `Suggested Action`
   - `Why`
   - `Proposed Resolution`

4. End each finding review with exactly two options.

   For non-final findings:
   1. `accept and continue`
   2. `adjust`

   For the final finding:
   1. `accept and view final summary`
   2. `adjust`

5. If the user chooses `adjust`, stay on that same finding until alignment is reached.
   - Do not advance to the next finding until the current one has an agreed outcome.
   - The agreed outcome may be:
     - a revised implementation plan
     - rejection of the finding
     - deferral of the finding
   - Record the agreed outcome before moving on.

6. After all findings are reviewed, present a final execution summary.
   Separate clearly:
   - changes to implement
   - changes intentionally not to implement
   - changes that require touching files outside the diff
   - any open questions that still block implementation

7. Wait for explicit approval before editing files.

8. Apply all approved changes in one batch.

### `assisted`

Use this mode for a rule-by-rule walkthrough with the user before making any edits.

1. Review the cleanup rules sequentially instead of starting with a full findings summary.

2. For each rule:
   - inspect the changed surface for that rule only
   - present a concise fact-based summary of what was found
   - propose what should change for that rule
   - ask the user to validate or adjust that direction before moving on

3. Keep a running internal record of:
   - approved changes
   - rejected changes
   - deferred questions

4. Do not edit files while walking through the rules.

5. After all rules are reviewed, present one final batch summary.
   Separate clearly:
   - approved edits
   - rejected edits
   - unresolved items

6. Wait for explicit approval before editing files.

7. Apply all approved changes in one batch.

## Decision Rules

- Prefer reuse over new helpers when the codebase already provides the needed behavior with little or no adaptation.
- Prefer a small extraction over copy-pasted private helpers when duplication is real and local.
- Prefer module moves only when the changed function clearly conflicts with the module's purpose or creates a better domain boundary.
- Prefer deleting unused state over preserving speculative future hooks.
- Prefer derived state over overlapping stored state when the derivation is cheap and clear.
- Prefer high-value specs on public or shared contracts over blanket typespec coverage on every function.
- Prefer concise docs and comments that explain intent or contract, not line-by-line mechanics.
- Prefer no change when evidence is weak.

## Guardrails

- Use facts from the diff and codebase. Do not guess.
- When writing or updating specs, do not invent `Module.t()` types. Confirm the referenced
  module exports that type first; otherwise use `%Module{}` or another real exported type.
- Do not add docs, specs, or comments to unchanged code just because a file changed.
- Do not expand cleanup into unrelated repo-wide refactors.
- Do not remove assigns, attrs, props, or helper code unless usage has been checked.
- Do not introduce comments with ticket IDs, person names, or ephemeral discussion context.
- Do not create speculative abstraction layers.
- Keep summaries concise and only go deep on the current finding or rule under discussion.
