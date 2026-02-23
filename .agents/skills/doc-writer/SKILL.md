---
name: doc-writer
description: Expert technical documentation writing and maintenance for the Torus codebase, covering both architecture-facing engineering docs and user-facing product docs. Use when drafting, restructuring, or updating docs for system architecture, feature behavior, onboarding guides, API/flow explanations, or end-user workflows for authors, students, instructors, admins, and LTI/Direct Delivery users.
---

# Torus Documentation Writer

Write clear, correct, concise, and complete Torus documentation for two audiences:

- Technical guide for software architects and engineers.
- User guide for authors, students, instructors, admins, and LTI/Direct Delivery users.

## Workflow

1. Determine audience and document intent.
   - Technical guide: architecture, domain model, implementation detail, operations, troubleshooting.
   - User guide: role-specific tasks, outcomes, UI behavior, prerequisites, troubleshooting.
2. Gather source-of-truth context from code and existing docs before writing.
   - Prefer concrete file/module references and observed behavior over assumptions.
   - When details are uncertain, call out assumptions explicitly.
3. Select structure from templates:
   - `assets/templates/technical-guide-template.md`
   - `assets/templates/user-guide-template.md`
4. Draft in concise sections with strong headings and scannable lists.
5. Verify for clarity, correctness, and completeness.
   - Validate terminology consistency (project, section, publication, revision, enrollment, attempt, etc.).
   - Ensure every workflow includes prerequisites, steps, outcomes, and failure cases.
6. Update docs in place and add cross-links to related Torus docs.

## Quality Bar

- Favor accuracy over coverage: do not invent behavior.
- Be concise, but include critical edge cases and constraints.
- Write for onboarding and long-term maintenance, not only immediate release notes.
- Keep language direct and plain; avoid marketing tone.
- Include concrete artifacts when possible:
  - file paths
  - module/context names
  - route names
  - user role scope
  - environment requirements

## Audience Rules

### Technical Guide (Architects/Engineers)

- Explain boundaries first: contexts, ownership, and interfaces.
- Document lifecycle/state transitions: authoring, publication, delivery, grading, analytics.
- Include implementation cues: key modules, event flows, data model touchpoints, background jobs, caching.
- Distinguish current behavior vs proposed/future behavior.
- Add troubleshooting with likely failure modes and diagnostics.

### User Guide (Authors/Students/Instructors/Admins/LTI/Direct Delivery)

- Organize by role and goal, not by internal implementation.
- Use action-first language and expected outcomes.
- Call out permissions and role limitations.
- Include role-specific troubleshooting and support escalation paths.
- Separate LTI and Direct Delivery flows when behavior diverges.

## Required References

Read these before substantial doc creation or edits:

- `references/writing-standards.md`
- `references/technical-guide-outline.md` when writing technical docs
- `references/user-guide-outline.md` when writing user-facing docs

## Deliverables

- Produce documentation that is immediately publishable with minimal editing.
- Keep sections independently readable.
- Include a short "Last reviewed" date line when creating or significantly updating a full guide.
- End each major guide with "Known limitations" and "Related documentation".

## Response Contract

- Start by naming the audience and intended doc artifact.
- Provide a proposed outline before full draft when scope is broad.
- Cite concrete Torus modules/paths for technical docs.
- For user guides, provide role-tagged steps and explicit outcomes.
