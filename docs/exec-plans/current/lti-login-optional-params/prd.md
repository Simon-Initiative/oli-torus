# LTI Login Optional Params - Product Requirements Document

## 1. Overview

Add LMS-parity optional parameters to Torus outbound LTI 1.3 external-tool login requests so third-party tools that expect common Canvas-style login inputs can launch successfully from Torus. The scope is limited to Torus acting as the platform for external tools and covers the launch-details API plus the browser form-post path that submits those values to the external tool.

## 2. Background & Problem Statement

Torus currently launches external LTI tools by generating a launch-details payload that includes the core OIDC login fields required to start a tool launch. Some vendors, including VitalSource, also expect optional parameters that many LMS platforms send in practice, specifically `lti_deployment_id` and `lti_message_hint`.

Although these fields are optional in the specification, omitting them creates an interoperability gap between Torus and mainstream LMS behavior. A tool that works when launched from Canvas may fail or degrade when launched from Torus because Torus does not provide the same optional login context. The result is avoidable launch failures for instructors and learners using external tools.

## 3. Goals & Non-Goals
### Goals
- Send `lti_deployment_id` in outbound external-tool login requests whenever Torus has a registered deployment for the tool launch.
- Send `lti_message_hint` in outbound external-tool login requests in a stable, non-sensitive form that tools can consume.
- Keep authoring, delivery, and deep-linking launch-details responses aligned so the same external tool receives consistent login inputs across Torus surfaces.
- Preserve pass-through behavior from the server-generated launch-details payload through the rendered HTML form submission.
- Add regression coverage that proves the optional parameters are present when expected and absent only when context is genuinely unavailable.

### Non-Goals
- Redesign inbound `/lti/login` behavior where Torus is launched as the tool by another LMS.
- Add vendor-specific launch branches or per-tool custom behavior beyond standards-recognized optional fields.
- Change the external tool registration UX or introduce new admin configuration fields unless implementation proves an existing field is missing.
- Redesign the id-token claims sent later in the external tool launch unless separately required by implementation.

## 4. Users & Use Cases
- Learners: open a course resource backed by an external tool and complete the launch without vendor-side rejection caused by missing optional login params.
- Instructors: preview and use external tools in delivery or authoring without seeing behavior differences versus a common LMS such as Canvas.
- Administrators configuring tools: register a tool once in Torus and expect launches to include the same practical login context that commercial LMS platforms usually provide.
- Support and engineering staff: diagnose external-tool launch issues without chasing false negatives caused by Torus omitting common optional login fields.

## 5. UX / UI Requirements
- External tool launch UX must remain unchanged apart from improved launch compatibility.
- Hidden form fields used to submit launch parameters must reflect the server-generated launch-details payload exactly for the supported optional params.
- If an optional param is unavailable, the client should omit it rather than rendering an empty or misleading hidden field.
- No new visible controls, prompts, or user education surfaces are required for this work item.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Reliability: authoring, delivery, and deep-linking launch paths must produce consistent optional-param behavior for the same external tool configuration.
- Security: `lti_message_hint` must not expose sensitive internal Torus state, raw session identifiers, or privileged data through browser-visible form fields.
- Maintainability: optional-param generation should live at the server boundary where launch params are assembled, not as ad hoc frontend mutation.
- Compatibility: the additional parameters must remain compatible with existing tools that ignore them.
- Performance: generating and returning the new optional params must not materially change launch-details latency.

## 9. Data, Interfaces & Dependencies
- The primary server boundary is [`lib/oli_web/controllers/api/lti_controller.ex`](./lib/oli_web/controllers/api/lti_controller.ex).
- The main client pass-through boundary is [`assets/src/components/lti/LTIExternalToolFrame.tsx`](./assets/src/components/lti/LTIExternalToolFrame.tsx).
- Type definitions for launch-details responses live in [`assets/src/data/persistence/lti_platform.ts`](./assets/src/data/persistence/lti_platform.ts).
- The external tool deployment model already has a deployment identifier through [`lib/oli/lti/platform_external_tools/lti_external_tool_activity_deployment.ex`](./lib/oli/lti/platform_external_tools/lti_external_tool_activity_deployment.ex).
- Torus depends on `Lti_1p3.Platform.LoginHints` for `login_hint`; this work may reuse that context or introduce a separate opaque hint value for `lti_message_hint`.

## 10. Repository & Platform Considerations
- Torus is a Phoenix application with React clients, so launch-param assembly should remain server-owned and the frontend should only render and submit what the API returns.
- Existing API coverage in [`test/oli_web/controllers/api/lti_controller_test.exs`](./test/oli_web/controllers/api/lti_controller_test.exs) should be extended rather than creating only manual verification.
- Existing component coverage around hidden launch fields should be extended where practical to prove optional-param rendering remains correct.
- The harness contract files named by the skill were not present in this repository, so this PRD is grounded in the available Torus code, tests, repo instructions, and current work-item patterns.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Primary success signal: affected external tools launch successfully from Torus without requiring vendor-specific exceptions.
- Manual verification should confirm the outbound login POST includes `lti_deployment_id` and `lti_message_hint` when inspected with an LTI debugging tool or browser tools.
- No new product telemetry is required unless implementation introduces a new failure mode that needs observability.

## 13. Risks & Mitigations
- Risk: `lti_message_hint` is populated with sensitive or unstable data. Mitigation: require an opaque, non-sensitive value and keep generation server-owned.
- Risk: one Torus launch surface includes the optional params while another omits them. Mitigation: define parity requirements across authoring, delivery, and deep-linking responses.
- Risk: adding fields to the API response breaks strict frontend typing or assumptions. Mitigation: update TypeScript response types and regression tests together.
- Risk: tools react poorly to empty optional params. Mitigation: omit unavailable values rather than sending blank strings.

## 14. Open Questions & Assumptions
### Open Questions
- What exact value should Torus use for `lti_message_hint` so it is both useful to tools and safely opaque from Torus’s perspective?
- Should deep-linking launches always include the same optional params as regular resource-link launches, or only when the external tool expects them for that message type?
- Are there existing external tool integrations besides VitalSource that require these params and should be called out in manual QA?

### Assumptions
- Torus can derive `lti_deployment_id` for external-tool launches from the deployment record associated with the activity registration.
- Tools that rely on these params will accept Torus-provided values as long as the fields are present and structurally valid.
- Adding optional params to the launch-details payload is backward compatible for tools that ignore them.
- The current hidden form-post launch path remains the correct submission mechanism for this work.

## 15. QA Plan
- Automated validation:
  - Extend API controller tests to assert `lti_deployment_id` and `lti_message_hint` are present in authoring and delivery launch-details responses when available.
  - Add or extend deep-linking launch-details tests if that path is expected to include the same optional params.
  - Extend component tests to confirm the launch form renders hidden inputs for the optional params and omits empty values.
  - Verify updated TypeScript types compile against the expanded launch-details payload.
- Manual validation:
  - Launch an affected external tool such as VitalSource from a Torus section and confirm the login request contains both optional params.
  - Use an LTI debugging tool or browser network inspection to confirm the submitted POST matches the server-generated launch params.
  - Verify a tool that ignores the optional params still launches successfully.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
