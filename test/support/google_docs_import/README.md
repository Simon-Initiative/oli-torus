This directory holds anonymised Markdown exports that drive the Google Docs importer test suite.
Each fixture focuses on a different slice of functionality and documents the Torus structures
that the importer must emit.

- `baseline.md` — Exercises headings, paragraphs, ordered/unordered lists, inline marks, and blockquotes.
  Expected output: standard Torus content blocks (heading, paragraph, list, quote) with marks preserved.
- `custom_elements.md` — Contains YouTube and MCQ CustomElement tables. Expected output: YouTube media block
  with caption and transcript URL plus a fully validated `oli_multiple_choice` activity derived from the MCQ table.
- `media.md` — Embeds duplicate base64 PNGs to validate hashing, deduplication, and fallback behaviour.
  Expected output: two image blocks referencing a single uploaded asset URL, plus warnings when uploads fail
  or exceed configured budgets.

When adding new fixtures, keep real PII out of the files and note the expected Torus structures here so tests can assert on them.
