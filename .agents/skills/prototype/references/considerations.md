# Considerations

- Keep prototype scope intentionally narrow and reversible.
- Avoid broad refactors or speculative architecture work.
- Skip full test suite and hardening by default unless user asks.
- Include enough instrumentation/logging to demo behavior and debug quickly.
- Respect critical safety constraints (no secrets in code, basic input sanity checks).
- Make unknowns explicit so transition to production is straightforward.
