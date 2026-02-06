# Link Validation Notes

- Default mode validates local links and anchor targets without network access.
- `--check-external-links` performs HTTP HEAD checks for external URLs; use this only when network access is available.
- Prefer relative links for in-repo docs so path checks are deterministic.
