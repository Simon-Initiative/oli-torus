# Informal Work Summary: External Tool LTI Login Optional Parameter Parity

## Why this work exists

Torus launches third-party LTI 1.3 external tools from authoring and delivery surfaces. Some tools, including VitalSource, expect the platform-initiated login step to include optional parameters that are commonly sent by major LMS platforms such as Canvas.

The ticket specifically calls out these parameters:

- `lti_deployment_id`
- `lti_message_hint`

These parameters are optional in the standard, but real integrations may still rely on them. When Torus omits them, external tools can reject or mishandle launches even though the core LTI flow is otherwise valid.

## Problem framing

Today, Torus already generates baseline launch parameters for external tool launches, including `iss`, `login_hint`, `client_id`, `target_link_uri`, and `login_url`. The current launch-details payload and UI form-post path do not clearly guarantee parity for the optional login parameters listed above.

That creates an interoperability gap:

- Torus behaves differently from common LMS platforms
- tool vendors may implicitly treat these fields as required in practice
- users encounter launch failures against tools that otherwise work in Canvas or similar LMSs

## Desired outcome

Torus should include LMS-parity optional parameters in outbound LTI login requests for external tools wherever Torus has the necessary context to do so, so standards-tolerant but ecosystem-dependent tools continue to work.

At minimum, the resulting behavior should ensure:

- `lti_deployment_id` is supplied for external-tool launches from the deployment record used to register the tool in Torus
- `lti_message_hint` is supplied for external-tool launches in a stable, tool-consumable, non-sensitive way
- the launch-details API and HTML form-post path preserve those values without mutating or dropping them
- missing optional values are handled predictably rather than causing malformed requests

## Scope

In scope:

- outbound LTI login launches from Torus to external tools
- authoring launch details
- delivery launch details
- deep-linking launch details if the same parity expectation applies there
- regression coverage for API payloads and rendered hidden inputs

Out of scope:

- inbound Torus `/lti/login` launches where Torus acts as the tool for an LMS
- broader external-tool registration UX changes
- vendor-specific workarounds beyond sending standards-recognized optional parameters
- changes to the external tool id-token launch payload unless separately required

## Risks and constraints

- `lti_message_hint` should be useful to the tool without exposing sensitive Torus state in a browser-visible hidden form field.
- Torus should not send blank or contradictory values for optional params.
- Authoring, delivery, and deep-linking launch paths should remain internally consistent so one surface does not diverge from another.

## Success signal

An external tool that expects these optional OIDC login parameters should receive them from Torus and launch successfully under the same configuration that works in a mainstream LMS.

## External references

- 1EdTech LTI 1.3 general details: `https://www.imsglobal.org/spec/lti/v1p3#lti-message-general-details`
- 1EdTech third-party initiated login: `https://www.imsglobal.org/spec/security/v1p0/#step-1-third-party-initiated-login`
- Chrome LTI Debugger extension: `https://chromewebstore.google.com/detail/lti-debugger/cpjdeioljkbgkldnbojoagdoiggnlhll`
