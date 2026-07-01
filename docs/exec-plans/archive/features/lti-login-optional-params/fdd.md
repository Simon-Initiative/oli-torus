# LTI Login Optional Params - Functional Design Document

## 1. Executive Summary

This design extends Torus’s external-tool launch-details API so outbound LTI login requests include `lti_deployment_id` and `lti_message_hint` without changing the visible launch UX. The simplest adequate approach is to keep launch-param assembly server-owned in [`lib/oli_web/controllers/api/lti_controller.ex`](./lib/oli_web/controllers/api/lti_controller.ex), add a shared builder used by authoring, delivery, and deep-linking responses, source `lti_deployment_id` from the existing external-tool deployment row, and generate `lti_message_hint` as a compact signed token carrying minimal launch context rather than reusing `login_hint`.

This design satisfies FR-001 through FR-005 while avoiding new storage, migrations, or frontend-side mutation. It directly targets AC-001, AC-002, AC-003, AC-004, and AC-005 by keeping the optional params in the same launch-details payload that already drives the hidden form POST to the external tool.

## 2. Requirements & Assumptions

- Functional requirements:
  - FR-001 requires the external-tool launch payload to include `lti_deployment_id`.
  - FR-002 requires `lti_message_hint` to be opaque and non-sensitive.
  - FR-003 requires parity across authoring, delivery, and supported deep-linking launch-details endpoints.
  - FR-004 requires the client form submission path to preserve the server-produced values unchanged.
  - FR-005 requires omission of values that cannot be derived, rather than empty placeholders.
- Non-functional requirements:
  - Keep launch-param generation at the Phoenix server boundary.
  - Avoid introducing a new persistence layer or stateful launch-message-hint artifact unless the current boundaries prove insufficient.
  - Preserve backward compatibility for tools that ignore the new params.
- Assumptions:
  - Every registered external-tool launch already has access to the `LtiExternalToolActivityDeployment` record and therefore its `deployment_id`.
  - External tools do not require Torus to persist `lti_message_hint`, but Torus may benefit from being able to verify and inspect the minimal launch context it issued if debugging becomes necessary.
  - A compact signed token carrying minimal launch context is sufficiently tool-compatible and closer to observed LMS behavior than duplicating `login_hint`.

## 3. Repository Context Summary

- What we know:
  - Authoring launch details, delivery launch details, and deep-linking launch details are assembled in [`lib/oli_web/controllers/api/lti_controller.ex`](./lib/oli_web/controllers/api/lti_controller.ex).
  - The JSON response shape is typed in [`assets/src/data/persistence/lti_platform.ts`](./assets/src/data/persistence/lti_platform.ts) and consumed directly by [`assets/src/components/lti/LTIExternalToolFrame.tsx`](./assets/src/components/lti/LTIExternalToolFrame.tsx).
  - `LTIExternalToolFrame` posts every key in `launchParams` except `login_url` as a hidden form input, so backend parity is the main contract boundary for AC-002.
  - Existing API tests in [`test/oli_web/controllers/api/lti_controller_test.exs`](./test/oli_web/controllers/api/lti_controller_test.exs) and [`test/oli_web/controllers/api/lti_controller_integration_test.exs`](./test/oli_web/controllers/api/lti_controller_integration_test.exs) already assert the response structure and are the right place to extend AC-001 and AC-003 coverage.
  - The external-tool deployment identifier already exists as the primary key on [`lib/oli/lti/platform_external_tools/lti_external_tool_activity_deployment.ex`](./lib/oli/lti/platform_external_tools/lti_external_tool_activity_deployment.ex), so FR-001 does not require a migration.
  - `login_hint` values are created by `Lti_1p3.Platform.LoginHints.create_login_hint/2` and are opaque UUIDs tied to stored context.
  - Phoenix already provides signed token primitives in the codebase, so Torus can issue a compact signed message hint without adding new persistence.
- Unknowns to confirm:
  - Whether any vendor expects `lti_message_hint` to encode semantics beyond an opaque correlation value.
  - Whether there are frontend tests for the React `LTIExternalToolFrame` path that should be extended in addition to the Phoenix component tests.
  - Whether any tool launch path outside the three API endpoints assembles launch params independently.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

Introduce private helpers in `OliWeb.Api.LtiController` to build the `launch_params` map and derive a distinct `lti_message_hint` for external-tool launches. Each endpoint will continue to resolve the tool deployment, create a `login_hint`, derive a compact signed message hint, and then call the shared builder with:

- platform instance
- generated `login_hint`
- derived `lti_message_hint`
- deployment record or deployment id
- launch context inputs used for derivation, such as activity id or resource id when available
- optional extra launch params such as `lti_message_type` for deep linking

The derivation helper will:

1. Assemble a minimal message-hint payload from current launch-specific values:
   - `deployment_id`
   - generated `login_hint`
   - `target_link_uri`
   - launch mode or endpoint type
   - `lti_message_type` when present
   - activity or resource identifier when available
2. Sign that payload with `Phoenix.Token` under an LTI-specific salt.
3. Return the signed token string as `lti_message_hint`.

The launch-param builder will:

1. Build the base launch params already in use: `iss`, `login_hint`, `client_id`, `target_link_uri`, `login_url`.
2. Add `lti_deployment_id` from the resolved `LtiExternalToolActivityDeployment.deployment_id`.
3. Add the signed `lti_message_hint`.
4. Merge any endpoint-specific extra params.
5. Drop nil values before encoding the JSON response.

This preserves the current layering:

- server owns launch-param construction
- TypeScript types describe the payload
- React form rendering passes values through unchanged

### 4.2 State & Data Flow

Authoring and delivery flow:

1. Controller resolves the external-tool deployment and platform instance.
2. Controller generates `login_hint` through `LoginHints.create_login_hint/2`.
3. Controller derives `lti_message_hint` from the current launch context and generated `login_hint`.
4. Controller calls the shared helper to build `launch_params`.
5. API response returns the expanded `launch_params`.
6. `LTIExternalToolFrame` renders hidden inputs for every param except `login_url`.
7. Browser POST submits `iss`, `login_hint`, `client_id`, `target_link_uri`, `lti_deployment_id`, and `lti_message_hint` to the external tool login endpoint. This is the AC-001 and AC-002 path.

Deep-linking flow:

1. Controller resolves the same deployment/platform boundaries as the standard launch.
2. Controller generates `login_hint`.
3. Controller derives `lti_message_hint` from the deep-linking launch context, including `lti_message_type`.
4. Shared helper builds the same optional params and merges `lti_message_type: "LtiDeepLinkingRequest"`.
5. Response shape stays structurally aligned with standard launch details. This is the AC-003 path.

Omission behavior:

- If `deployment_id` is unexpectedly nil, the helper omits `lti_deployment_id`.
- If `login_hint` generation somehow fails, the endpoint should continue to fail as it does today rather than fabricate inconsistent values.
- If `lti_message_hint` signing fails, the endpoint should omit that field rather than reusing `login_hint` or emitting a raw context structure.
- Nil removal in the helper enforces AC-004.

### 4.3 Lifecycle & Ownership

- `OliWeb.Api.LtiController` owns launch-param assembly.
- `Lti_1p3.Platform.LoginHints` continues to own creation and storage of the opaque UUID used for `login_hint`.
- `OliWeb.Api.LtiController` owns `lti_message_hint` derivation because the token is issued at the launch-details boundary and does not currently need a reusable domain model.
- `LtiExternalToolActivityDeployment` continues to own the persisted deployment identifier.
- `assets/src/data/persistence/lti_platform.ts` owns the client-side contract shape for these params.
- `assets/src/components/lti/LTIExternalToolFrame.tsx` owns transport only; it does not synthesize, rename, or filter the optional params other than the existing `login_url` exclusion.

### 4.4 Alternatives Considered

Alternative 1: create a dedicated `lti_message_hint` storage artifact.

- Rejected because it adds persistence and lifecycle complexity without a clear Torus-side consumer.
- A request-local signed token yields an opaque value without adding cleanup or state-recovery logic.

Alternative 2: generate a signed Phoenix token for `lti_message_hint`.

- Chosen because it keeps the value opaque externally while allowing Torus to preserve minimal launch semantics in a compact token, which is closer to observed Canvas behavior.
- It avoids persistence and gives Torus a stable, debuggable issuance boundary if later verification is needed.

Alternative 3: use `deployment_id` as `lti_message_hint`.

- Rejected because it collapses two logically different params into the same identifier and does not preserve the “opaque hint” intent in FR-002.

Alternative 4: reuse `login_hint` as `lti_message_hint`.

- Rejected because it does not align well with the spec’s intent that `lti_message_hint` carry message-specific context alongside `login_hint`.
- Keeping the values distinct preserves clearer semantics while still avoiding persistence.

Chosen approach: derive `lti_message_hint` as a signed compact token carrying minimal launch context and keep `lti_deployment_id` distinct. This is the simplest design that better aligns with the spec intent behind FR-002 and observed LMS behavior while still satisfying FR-001, FR-003, and FR-005 without schema changes.

## 5. Interfaces

- `OliWeb.Api.LtiController` private helper:
  - Input: platform instance, `login_hint :: String.t()`, `lti_message_hint :: String.t() | nil`, `deployment_id :: String.t() | nil`, `extra_params :: map`.
  - Output: launch params map with nil keys removed.
- `OliWeb.Api.LtiController` private derivation helper:
  - Input: `deployment_id`, `login_hint`, `target_link_uri`, launch mode, optional `lti_message_type`, optional activity or resource id.
  - Output: `lti_message_hint :: String.t()` as a signed token string.
- Authoring response contract:
  - `launch_params` gains optional keys `lti_deployment_id` and `lti_message_hint`.
- Delivery response contract:
  - `launch_params` gains optional keys `lti_deployment_id` and `lti_message_hint`.
- Deep-linking response contract:
  - `launch_params` retains `lti_message_type` and also gains `lti_deployment_id` and `lti_message_hint`.
- TypeScript interface update in `assets/src/data/persistence/lti_platform.ts`:
  - Add `lti_deployment_id?: string`
  - Add `lti_message_hint?: string`
- Browser form contract in `LTIExternalToolFrame`:
  - No behavior change; the component already posts arbitrary launch param keys and therefore fulfills FR-004 once the API payload includes the new values.

## 6. Data Model & Storage

- No schema changes.
- No new tables or background cleanup work.
- Existing storage reused:
  - `lti_external_tool_activity_deployments.deployment_id` for `lti_deployment_id`
  - `login_hints.value` for `login_hint`
- Derived request-local data:
  - `lti_message_hint` generated from minimal launch context and not persisted
- No migration is required.

## 7. Consistency & Transactions

- There is no new transaction boundary.
- Launch-details generation remains request-scoped.
- Consistency is achieved by using one helper for all three endpoints instead of duplicating map assembly logic.
- A single derivation helper ensures the API cannot accidentally vary `lti_message_hint` payload shape or signing policy across endpoints for equivalent launch contexts.

## 8. Caching Strategy

- N/A
- The design does not introduce caches or change existing cache behavior.

## 9. Performance & Scalability Posture

- The added work is a constant-size map merge and nil-compaction per request.
- No extra database queries are required if the controller uses the already-resolved deployment data.
- Phoenix token signing is CPU-local and avoids any second persistence call, keeping the current launch-details latency profile intact.

## 10. Failure Modes & Resilience

- Missing deployment id on a supposedly registered tool:
  - Response omits `lti_deployment_id` rather than sending `""`.
  - This supports AC-004 and makes the defect observable in tests rather than silently producing malformed requests.
- Failure creating `login_hint`:
  - Existing endpoint failure behavior remains authoritative; do not fabricate a fallback hint.
- Failure deriving `lti_message_hint`:
  - Omit the field rather than substituting `login_hint` or emitting an unsigned raw context structure.
  - Keep the failure local to this optional parameter to preserve launch behavior for tools that ignore it.
- One endpoint forgets to include the new fields:
  - Mitigated by consolidating launch-param assembly and by API tests that explicitly cover AC-001 and AC-003.
- Frontend drops the new fields:
  - Mitigated by the existing generic form rendering plus targeted AC-002 test coverage.
- Tools ignore the new fields:
  - No user-facing change; launch behavior remains backward compatible. This is AC-005.

## 11. Observability

- No new telemetry is required for this work item.
- Add lightweight debug logging around external-tool launch param generation to support future debugging.
- The logging should confirm whether `lti_deployment_id` and `lti_message_hint` were issued for a launch path without logging raw signed token payloads or other sensitive values.
- Existing request logs are otherwise sufficient because the behavior change is deterministic and covered by tests.

## 12. Security & Privacy

- A signed token carrying minimal launch context is opaque in the outbound payload and does not expose raw session ids, user ids, or readable message context to clients.
- The derivation helper must keep the payload minimal and must never include email, names, roles, or other unnecessary claims.
- The signing salt must be LTI-specific so the token is scoped to this use case.
- The design does not expose session ids, user ids, emails, or internal role data in browser-visible hidden inputs.
- `lti_deployment_id` is an integration identifier, not a secret, and is already intrinsic to the external-tool deployment relationship.
- No new authorization boundary is introduced because the same users who can request launch details today will continue to do so.

## 13. Testing Strategy

- Extend `test/oli_web/controllers/api/lti_controller_test.exs`:
  - Authoring `launch_details` asserts `lti_deployment_id` and `lti_message_hint` are present. AC-001.
  - Delivery `launch_details` asserts the same parity. AC-001.
  - Add an assertion that `lti_message_hint` is distinct from `login_hint`. AC-001.
- Extend `test/oli_web/controllers/api/lti_controller_integration_test.exs`:
  - Authoring response-structure test includes the new keys. AC-001.
  - Delivery response-structure test includes the new keys. AC-001.
  - Deep-linking response-structure test includes the new keys alongside `lti_message_type`. AC-003.
  - Add a parity assertion that `lti_message_hint` is present as a signed token string and that deep-linking changes the token when `lti_message_type` differs. AC-003.
- Extend launch form tests:
  - Add unit-level form-rendering assertions for hidden inputs carrying `lti_deployment_id` and `lti_message_hint`. AC-002.
  - Keep API response-shape assertions and form-rendering assertions separate; do not add backend/frontend integration tests to exercise this behavior end to end.
  - If React-side unit tests are added for [`LTIExternalToolFrame.tsx`](./assets/src/components/lti/LTIExternalToolFrame.tsx), they are the best place to assert pass-through behavior directly. Otherwise extend [`test/oli_web/components/delivery/lti_external_tools_test.exs`](./test/oli_web/components/delivery/lti_external_tools_test.exs). AC-002.
- Add a nil-omission unit or controller test:
  - Construct a launch-details case with a nil optional field and assert the response omits the key instead of returning an empty string. AC-004.
- Add a derivation helper unit test:
  - Verify the signed payload includes only the minimal expected launch fields and can be verified with the configured salt. AC-003.
- Backward-compatibility validation:
  - Run an existing external-tool launch path and confirm no user-facing behavior change other than the extra hidden inputs. AC-005.

## 14. Backwards Compatibility

- Existing clients that ignore the new keys remain compatible because the response is additive.
- Existing external tools that ignore optional params continue to receive the same required fields.
- Existing frontend rendering remains compatible because it already accepts arbitrary launch param keys.
- No migration or rollout sequencing is needed.

## 15. Risks & Mitigations

- Risk: a vendor expects `lti_message_hint` semantics richer than an opaque correlation string.
  - Mitigation: choose a message-derived opaque value first; if real integrations prove they need richer semantics, evolve behind the same helper without changing the public endpoint shape.
- Risk: the signed payload includes too much context and leaks unnecessary metadata if decoded outside Torus.
  - Mitigation: keep the payload minimal and explicitly exclude user identifiers, roles, and other nonessential fields.
- Risk: token salt or signing policy changes break stability expectations across endpoints.
  - Mitigation: isolate issuance in one helper and add unit tests that verify sign/verify behavior with the dedicated salt.
- Risk: duplicate map assembly persists across endpoints and causes drift.
  - Mitigation: centralize launch-param construction in one private helper.
- Risk: tests cover only API payloads and miss actual form pass-through.
  - Mitigation: add AC-002 form-rendering coverage, not just controller assertions.
- Risk: a nil deployment id indicates a deeper data issue for a registered tool.
  - Mitigation: omit the field, keep tests explicit, and treat the nil case as a detectable defect rather than hiding it with an empty string.

## 16. Open Questions & Follow-ups

- No open questions remain for this design.
- Follow-up: keep `lti_message_hint` token issuance private to `OliWeb.Api.LtiController` unless a new external-tool launch surface is introduced.
- Follow-up: implement lightweight debug logging around external-tool launch param generation as part of this work item.

## 17. References

- PRD: [prd.md](./docs/exec-plans/current/lti-login-optional-params/prd.md)
- Requirements: [requirements.yml](./docs/exec-plans/current/lti-login-optional-params/requirements.yml)
- API controller: [lti_controller.ex](./lib/oli_web/controllers/api/lti_controller.ex)
- TypeScript contract: [lti_platform.ts](./assets/src/data/persistence/lti_platform.ts)
- Launch form component: [LTIExternalToolFrame.tsx](./assets/src/components/lti/LTIExternalToolFrame.tsx)
- Delivery component tests: [lti_external_tools_test.exs](./test/oli_web/components/delivery/lti_external_tools_test.exs)
- API tests: [lti_controller_test.exs](./test/oli_web/controllers/api/lti_controller_test.exs)
- API integration tests: [lti_controller_integration_test.exs](./test/oli_web/controllers/api/lti_controller_integration_test.exs)
