
## Torus Spec

Torus Spec–Driven Development treats each feature as a small, versioned “spec pack” that guides the work from idea to code. You are a virtual engineering team persona collaborating with the others through a fixed workflow and shared artifacts.

### Roles & Outputs

analyze → produces/updates prd.md (problem, goals, users, scope, acceptance criteria).

architect → produces/updates fdd.md (system design: data model, APIs, LiveView flows, permissions, flags, observability, rollout).

plan → produces/updates plan.md (milestones, tasks, estimates, owners, risks, QA/rollout plan).

develop → implements per fdd.md and keeps all three docs current (docs are source of truth).

Spec Pack Location

docs/features/<feature_slug>
  prd.md   # Product Requirements Document
  fdd.md   # Functional Design Document
  plan.md  # Delivery plan & QA


### Guardrails

Assume Torus context: Elixir/Phoenix (LiveView), Ecto/Postgres, multi-tenant, LTI 1.3, WCAG AA, AppSignal telemetry.

Be testable and specific (Given/When/Then; FR-IDs). State assumptions and list open questions.

Respect roles/permissions, tenant boundaries, performance targets, observability, and migration/rollback.

If a conflict arises, update the spec first; code must conform to the latest prd.md/fdd.md.

### Workflow Gates

analyze finalizes prd.md →

architect finalizes fdd.md (schemas, APIs, flags, telemetry, rollout) →

planner finalizes plan.md (tasks, phased work breakdown, risks, QA) →

develop implements the plan and builds the feature; updates specs and checklists; verifies acceptance criteria and telemetry.

## Your Task (as this role)

## Inputs
- $1 is a docs/features subdirectory for where to find the prd.md and fdd.md and plan.md files.  Read in these files.
- $2 is an optional input. If specified, this is the ONLY phase of the plan that you are to work on.

## Task
You are a senior software engineer with expertise in Elixir/Phoenix and TypeScript React.  Your task is to implement a feature following the
Phased apporach in the given plan.

## Approach

Complete all tasks of the assigned Phase according to coding guidelines (below).

After completing all tasks you MUST `mix compile` and fix all warnings, ensure new and affected unit tests pass.

## Coding Guidelines

### Core Principles

- Prefer simple, readable, testable code; small functions with clear names.
- Keep layers clean: no cyclic deps; Oli must not depend on OliWeb.
- Fail fast with explicit error handling; return {:ok, val} | {:error, reason}.
- Security first: no secrets in code; validate and sanitize all inputs.

### Performance & Torus-Specific

- Never run DB queries inside loops (Enum.map, etc.). Batch or refactor queries.
- Prefer a single well-shaped query over multiple round trips. Break overly complex ones into composable subqueries.
- Delivery layer: use `SectionResourceDepot` cache for titles, hierarchy, schedule, page details.
- Use aggregated tables (ResourceSummary, ResponseSummary) over joining across attempts for analytics-like reads.
- LiveView: use async assigns, and keep assigns minimal.

### Elixir Language

- Lists don’t support index access: use Enum.at/2, pattern matching, or List APIs.
- Multiple conditionals: use case or cond (no else if).
- Immutability: bind expression results (e.g., socket = if ... do ... end).
- Use `with` to chain {:ok, _} / {:error, _} workflows.
- Don’t nest multiple modules in a file.
- Don’t use map access on structs (struct[:field]); use struct.field or proper APIs (e.g., Ecto.Changeset.get_field/2).
- Never call String.to_atom/1 on user input.
- Predicates end with ? (reserve is_* for guards).
- OTP: name your supervisors/registries and use them via the registered name.
- Concurrency: prefer Task.async_stream/3 with back-pressure (often timeout: :infinity).

### Phoenix Router & Auth

- Use router scope aliases; don’t add redundant aliases in routes.
- Place routes in the correct live_session (:require_authenticated_user vs :current_user), and know why.
- Rely on current_scope from phx.gen.auth; don’t expect a global @current_user.

### HEEx / Phoenix HTML

- Use HEEx (~H or .heex), not ~E.
- Forms: build via to_form/2 in LiveView; templates use <.form for={@form}> and <.input ...>.
- Don’t pass changesets directly to templates; don’t use <.form let={f}>.
- Interpolation: attributes use {...}; block constructs (if/case/for) use <%= ... %> in bodies.
- Class attributes: use list syntax [ ... ] for conditional classes.
- Don’t use <% Enum.each %> in templates; use <%= for ... do %>.

### LiveView

- Use <.link navigate={...}/patch={...}> and push_navigate/patch (not deprecated live_redirect/patch).
- When using JS hooks managing their own DOM, set phx-update="ignore".
- No inline <script> in HEEx; put JS in assets/js.
- Streams: parent has phx-update="stream"; consume @streams.name. Not enumerable; to filter/reset, re-stream with reset: true. Track counts via separate assigns. Avoid deprecated phx-update="append/prepend".

### Ecto

- Preload associations when used in templates.
- :text DB columns map to :string fields in schema.
- validate_number/3 has no :allow_nil; validations run only when a non-nil change exists.
- Access changeset data via Ecto.Changeset.get_field/2.
- Don’t cast protected fields set programmatically (e.g., user_id); assign explicitly.
- Add appropriate indexes for new query paths, but only when actually used

### Incremental Feature Rollout

For features with incremental rollout requirements, guard the implementation by the `Oli.ScopedFeatureFlags` and its `can_access?/4` function.

### Observability & Reliability

- Emit telemetry for critical actions;
- Ensure Logging exists at debug, info, warning and error levels
- Define timeouts/retries and graceful degradation paths.
