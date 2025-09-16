# Requirements Review Checklist (`requirements.md`)

> Goal: ensure **every requirement in the PRD is implemented, correct, and test-verified**. Use this file during PR review to run a structured, repeatable requirements check. Leave **specific, actionable** comments (file:line + suggested fix).

---

## 0) Inputs & Scope

- [ ] **PRD version & scope confirmed**
  - Link PRD + version/hash/date; note non-functional requirements (NFRs) and out-of-scope items.
  - Map PR to specific PRD sections (features, user stories, acceptance criteria).
- [ ] **Design artifacts**: UX mocks/flows, API schemas (OpenAPI/GraphQL), data model/migration notes.
- [ ] **Release artifacts**: feature flags, rollout plan, migration plan, monitoring plan, revert plan.
- [ ] **Test artifacts**: test plan, coverage report, mutation test report (if available), e2e results.

---

## 1) Build a Quick Trace (Requirements → Code → Tests)

Create or validate a **Requirements Traceability Matrix (RTM)**.

| Req ID | PRD Paragraph/AC | Implementation (files/lines) | Tests (files/cases) | Status |
|-------:|-------------------|-------------------------------|---------------------|--------|
| R-1    | §2.1, AC-A/B/C    | `app/.../svc.ex:12–80`, `.../controller.ex:30–90` | `test/.../svc_test.exs::*`, `e2e/...feature:Scenarios` | ✅ |
| R-2    | §2.2              | …                             | …                   | 🔶 (partial) |
| R-3    | §2.3 (NFR: perf)  | …                             | perf/a11y tests     | ❌ |

**Rules**
- Each **functional** and **non-functional** requirement has:
  - [ ] At least one concrete implementation location.
  - [ ] At least one test that **proves** it (unit/integration/e2e as appropriate).
- Gaps are explicitly listed with an owner + follow-up.

---

## 2) Functional Requirements (per Acceptance Criteria)

For **each** PRD acceptance criterion (AC):

- [ ] **Happy path** implemented and tested.
- [ ] **Edge cases** covered (empty input, max/min limits, null/undefined, time/date boundaries, pagination ends, 0/1/N items).
- [ ] **Negative & error paths** (invalid input, permission denied, backend failures) return the **specified** error codes/messages and are tested.
- [ ] **State transitions** (draft → published, enabled/disabled) are correct & tested.
- [ ] **Idempotency** where required (retries, duplicate submits).
- [ ] **Localization** (copy externalized; date/number formats).
- [ ] **Analytics/telemetry events** emitted with correct schema and are test-asserted (shape + count).

---

## 3) Non-Functional Requirements (NFRs)

Confirm implementation + **evidence** (benchmarks, configs, tests). Mark N/A only if PRD explicitly excludes.

- **Performance**
  - [ ] Latency/throughput targets documented and **measured** (before/after).
  - [ ] No N+1; no queries inside loops; streaming/batching used where needed.
  - [ ] Large lists virtualized/paginated; images/assets optimized.
- **Security**
  - [ ] AuthZ decisions enforced server-side; sensitive fields not mass-assignable.
  - [ ] Input validation/sanitization at boundaries; secrets not logged.
  - [ ] CSRF/CORS/headers as applicable; scans (e.g., Sobelow) reviewed.
- **Accessibility**
  - [ ] Semantics, keyboard, focus, color contrast; forms have labels; a11y checks (axe) pass.
- **Reliability/Resilience**
  - [ ] Timeouts, retries with backoff, circuit breakers; idempotent handlers.
  - [ ] Degradation paths defined; queues bounded; no unbounded concurrency.
- **Privacy/Compliance**
  - [ ] Data minimization; retention/erasure flows; PII masked in logs/telemetry.
- **Observability**
  - [ ] Metrics (p50/p95/p99), logs (structured), traces added at critical paths; alerts defined.
- **Internationalization**
  - [ ] Text externalized; pluralization/gender rules; RTL/expansion considered.

---

## 4) Data Model & Migrations

- [ ] Schema changes match PRD; column types/constraints/indexes documented.
- [ ] Migrations are **reversible**; a **rollback plan** exists.

---

## 5) API & Contract Checks

- [ ] OpenAPI schemas updated; versioning rules followed (no breaking changes without version bump).
- [ ] **Request/response** validation (runtime schema) and **error model** match PRD.
- [ ] Contract tests for **consumers** (mock or real) cover required shapes and edge cases.
- [ ] Rate limits, pagination, sorting, filtering semantics align with PRD and are tested.

---

## 6) Test Plan & Effectiveness

### Expected Test Mix (by requirement)
- **Unit tests** for pure logic (branch & boundary coverage).
- **Scenario tests** for non UI integration testing using Oli.Scenarios
- **Contract tests** for externalized APIs/clients.
- **Property-based** where invariants exist (parsers, serializers, math).

### Quality Gates
- [ ] Coverage budget met **where it matters** (changed files/critical modules). % is not the only signal.
- [ ] **Mutation testing** (if available) shows low survivor rate on changed code.
- [ ] **Flaky tests** not introduced; async tests use waits with conditions, not fixed sleeps.
- [ ] Test data reflects **realistic** shapes and edge values (min/max/empty/special chars, locale, timezones).

### “Test the tests” Heuristics
- Can you **break** the feature by changing a line and still have tests pass? If yes, tests are weak.
- Are **error branches** and **timeouts** asserted?
- Are **permission denials** and **multi-tenant fences** asserted?

---

## 7) Untested / Under-tested Hotspots (Reviewer Heuristics)

If missing or thin, call out explicitly with file:line.

- Error handling branches (`{:error, _}`, exceptions thrown).
- Timeouts, cancellations, retries, and partial failures.
- Pagination edges (page 1, last page, empty results).
- Concurrency/race conditions (double submit, dedupe keys).
- Data migration/backfill scripts (idempotency, resume after failure).
- Security boundaries (AuthZ checks, role/tenant separation).
- Localization (non-English, long strings, RTL).
- Date/time math (DST changes, leap days, timezone conversions).
- Large payloads/attachments; upload limits; streaming paths.
- Telemetry/analytics (event fires exactly once with correct shape).

---

## 8) Reviewer Red Flags (paste as actionable comments)

- “PRD **R-3** requires pagination caps; current API returns unbounded results. Add `limit`, `nextCursor`, and tests (`api_pagination_test.exs:...`).”
- “No negative tests for permission errors (AC-B). Add tests for viewer vs. editor roles.”
- “Migration lacks rollback and backfill idempotency. Provide reversible migration + chunked backfill with progress logging.”