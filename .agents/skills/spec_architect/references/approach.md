# Approach

Follow this sequence to produce the FDD:

1. Study the PRD (or informal description when PRD is incomplete).
2. Ingest local Torus design docs from `guides/design/**/*.md`; and other relevent feature or epic docs from `docs` and build a "What I know / Unknowns" list.
3. Perform lightweight codebase waypointing:
   - Relevant contexts and schemas.
   - LiveViews/controllers and request/event entry points.
   - Background jobs/tasks and supervision placement.
   - Caches and existing telemetry hooks.
4. Restate requirements in your own words:
   - Explicit goals and non-goals.
   - Constraints and success criteria.
   - Performance and reliability expectations.
5. Document assumptions explicitly; do not block on missing information. Record risks introduced by each assumption.
6. Perform external research when needed:
   - Prefer primary sources (official docs, HexDocs, Erlang/BEAM docs, Phoenix docs, posts by project maintainers).
   - Capture citations in FDD section 17 with title, URL, and access date.
7. Iterate design options and pick the approach that best satisfies FRs and NFRs with clear tradeoffs.
