# Slice Design Checklist

- Use sections from `assets/templates/design_slice_template.md`.
- Keep slice scope tight; defer unrelated work.
- Include explicit AC-to-slice mapping with IDs.
- Include concrete function/interface signatures.
- Cover edge cases and error behavior.
- Include a test plan for happy and failure paths.
- Include explicit scenario-test stance (`Required`/`Suggested`/`Not applicable`) for the slice.
- If scenario status is `Required` or `Suggested`, include scenario artifacts and validation commands.
- Include explicit LiveView-test stance (`Required`/`Suggested`/`Not applicable`) for the slice.
- If LiveView status is `Required` or `Suggested`, include LiveView test artifacts and commands.
- Remove unresolved `TODO`/`TBD`/`FIXME` markers.
