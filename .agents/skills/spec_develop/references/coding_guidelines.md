# Coding Guidelines

## Core Principles

- Prefer simple, readable, testable code; small functions with clear names.
- Keep layers clean: avoid cyclic dependencies; `Oli` must not depend on `OliWeb`.
- Fail fast with explicit error handling (`{:ok, value}` / `{:error, reason}` style where appropriate).
- Security first: no secrets in code; validate and sanitize external inputs.

## Performance and Torus-Specific

- Never run DB queries in loops; batch or reshape queries.
- Prefer a single well-shaped query over many round trips.
- Use `SectionResourceDepot` for delivery-layer cached reads (titles/hierarchy/schedule/page details) where relevant.
- Prefer summary/aggregated tables for analytics-style reads instead of expensive attempts joins.
- Keep LiveView assigns minimal; use async patterns for expensive reads/work.

## Elixir Language

- Lists do not support index access; use list/enum APIs and pattern matching.
- For branching, prefer `case`/`cond` over chained `else if` style.
- Respect immutability by rebinding expression results.
- Use `with` for multi-step success/error flows.
- Avoid defining multiple modules in a single file.
- Do not use map access syntax on structs (`struct[:field]`); use field access or proper APIs.
- Never call `String.to_atom/1` on user input.
- Predicate functions should end in `?`.
- Name supervisors/registries and use registered names consistently.
- For parallel work, prefer back-pressure-aware patterns (`Task.async_stream/3` with explicit options).

## Phoenix Router and Auth

- Use router scope aliases; avoid redundant route aliases.
- Place routes in the correct `live_session` and document why.
- Use `current_scope` conventions from `phx.gen.auth`; do not assume a global `@current_user`.

## HEEx / Phoenix HTML

- Use HEEx (`~H` / `.heex`) rather than legacy templates.
- Build forms with `to_form/2` in LiveView and `<.form for={@form}>` in templates.
- Do not pass raw changesets directly to templates.
- Use proper HEEx interpolation for attributes and body blocks.
- Use list syntax for conditional classes.
- Use `<%= for ... do %>` instead of side-effect iteration in templates.

## LiveView

- Use modern navigation APIs (`<.link navigate|patch>`, `push_navigate`, `push_patch`).
- Use `phx-update="ignore"` when a JS hook owns its DOM subtree.
- Do not place inline `<script>` in HEEx; keep JS in `assets/js`.
- Follow stream semantics correctly (`phx-update="stream"` and `@streams.*` patterns).

## Ecto

- Preload associations needed by templates.
- Use `:string` schema fields for `:text` DB columns.
- Avoid invalid `validate_number/3` options like `:allow_nil`.
- Access changeset values through `Ecto.Changeset.get_field/2` as needed.
- Do not cast protected fields that should be assigned programmatically.
- Add indexes for new query paths when they are actually used.

## Observability and Reliability

- Emit telemetry for critical actions and failures.
- Ensure logging coverage at appropriate levels for diagnostics.
- Define timeout/retry behavior and graceful degradation paths.
