# Accessibility regression coverage

The `accessibility-regression.spec.ts` suite uses the existing Playwright and
scenario infrastructure. Axe violations fail the test and include the page,
rule, impact, help text, and affected selector in the error output.

The cookie consent container is excluded from axe scans because it currently
has a known contrast issue. This is intentionally scoped to
`#cookie_consent_display`; it should be removed when that component is fixed.

The suite covers automated WCAG checks and keyboard focus smoke assertions.
VoiceOver, NVDA, and other real assistive-technology checks remain manual.
