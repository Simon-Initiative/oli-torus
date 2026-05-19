# Security

## Requirements

Security guidance in this repository should stay high level. This is an open source codebase, so this document should describe security boundaries and expectations without turning into an operational hardening checklist or exposing deployment-specific details.

- Torus relies on HTTPS / SSL as a core transport security requirement in real deployments.
- Session and cookie-based authentication are part of the normal web security model for the application.
- Torus supports LTI 1.3 as a major security and interoperability boundary for LMS-integrated delivery.
- Torus supports OAuth-based social login flows through external identity providers.
- Authentication and authorization must remain enforced on the server side, not only in UI behavior.
- Institution, role, section, and delivery context boundaries are part of the security model and must be preserved in application code.
- Sensitive configuration, credentials, signing material, and deployment secrets should be provided at runtime, not committed into the repository.
- Security review is mandatory for all substantive code reviews; use `.review/security.md` as the canonical review checklist.

## Canonical References

- Security review checklist: `.review/security.md`
- LTI security and integration docs: `guides/lti/implementing.md`, `guides/lti/config.md`
- GDPR and cookie-consent notes: `docs/design-docs/gdpr.md`
- Runtime and deployment configuration: `config/runtime.exs`, `guides/starting/self-hosted.md`
