# FDD Checklist

- Keep all required sections from `assets/templates/fdd_template.md`.
- Ensure sections 1-4 are complete and concrete (always required).
- Map design decisions back to PRD FR/AC IDs.
- Document assumptions explicitly.
- Include Torus context findings from `guides/design/**/*.md` and code waypointing.
- Specify module boundaries and interface contracts.
- Include migration and rollback considerations for schema changes.
- Include observability, security/privacy, and performance/scalability sections.
- Document feature flags/config toggles and rollout/rollback posture (or explicitly state none).
- Include concrete testing strategy and failure-mode handling.
- Include references for external research when used (`Title | URL | Accessed YYYY-MM-DD`).
- Do not include dedicated traffic-simulation test plans or tooling scenarios.
- Remove unresolved `TODO`/`TBD`/`FIXME` markers.
