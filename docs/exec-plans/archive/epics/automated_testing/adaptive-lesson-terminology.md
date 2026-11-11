# Adaptive lesson terminology

Canonical vocabulary for adaptive-lesson Playwright work. Counts are from the Living on the Edge
course archive (2026-07-31) and are illustrative, not limits.

Link to a definition from other docs with `[Activity](./adaptive-lesson-terminology.md#activity)`.

---

## Content hierarchy

| Level | Term | Count in LotE | Testing unit |
|---|---|---|---|
| 1 | [Page](#page) | 19 adaptive | one Playwright test |
| 2 | [Activity](#activity) | 557 (385 adaptive) | one ledger entry |
| 3 | [Part](#part) | ~4,600 | one receipt entry |
| 4 | [Widget](#widget) | 281 iframes | registry lookup |

### Page

A Torus page. When adaptive, its `content.model` holds a single `group` whose `children` are
`activity-reference` entries — the ordered list of screens. **One adaptive page = one Playwright
test**, because deck state accumulates across screens and a run cannot start in the middle.

Archive shape:

```
content.model[0].children[] = { activity_id, custom: { sequenceId, sequenceName } }
```

### Activity

One **screen** in the deck — what the learner sees at a single moment. Stored as its own archive
file named by `activity_id`. Carries `content.partsLayout` (its parts) and
`content.authoring.rules` (its adaptive rules).

Referred to as a *screen* throughout the driver and docs; the two words are interchangeable.
**One activity = one ledger entry** in the strict oracle.

Identity at runtime: the deck serialises `model.id` (= the archive's `custom.sequenceId`) and
`model.resourceId` (= `activity_id`) onto the delivery element. See
[screen identity](#screen-identity).

### Part

An element inside an activity's `partsLayout`. Most are inert (text, images); some are
interactive. Part types measured in LotE:

| Part type | Count | Interactive |
|---|---|---|
| `janus-text-flow` | 3,095 | no |
| `janus-image` | 620 | no |
| `janus-capi-iframe` | 281 | hosts a [widget](#widget) |
| `janus-mcq` | 230 | yes |
| `janus-popup` | 158 | no |
| `janus-multi-line-text` | 65 | yes |
| `janus-video` | 61 | gating only |
| `janus-dropdown` | 55 | yes |
| `janus-slider` | 8 | yes |
| `janus-input-number` | 8 | yes |

A part's state reaches the server under `stage.<partId>.<key>` — e.g. a `janus-mcq` submits
`stage.<id>.selectedChoiceText`, a `janus-multi-line-text` submits `stage.<id>.text`. That path is
what the [receipt](#receipt) correlates against.

### Widget

An **external application** loaded inside a `janus-capi-iframe` part, hosted off-platform
(`sim.argos.education`). A widget is *not* an activity and *not* a part — it lives inside a part.

Widgets in LotE:

| Widget | Count | Answers? |
|---|---|---|
| `spr-widget-buttonwidget` | 87 | no — navigation |
| `spr-widget-fill-in-the-blanks` | 56 | yes |
| `spr-widget-carousel` | 45 | no — content gating |
| `spr-widget-hotspot` | 20 | yes (not yet driven) |
| `spr-widget-timer` | 19 | no — chrome |
| `spr-widget-matching` | 13 | yes |
| `spr-widget-order-list` | 10 | yes |
| `spr-widget-grouping` | 10 | yes |
| `spr-widget-general-drag-drop` | 10 | yes |
| `spr-widget-image-scrub` | 2 | no |

Widgets communicate with the deck over CAPI (`postMessage`), **not** through the DOM. A
programmatic DOM change the widget did not originate is invisible to it — the defect class that
left every fill-in-the-blank submission empty. Their state arrives asynchronously, so it must be
observed via the deck's deferred save, not assumed after a delay.

### Widget version

A CAPI widget's URL carries its build: `.../sim/spr-widget-<family>/prod/<N>.*`. **The same family
can appear in several versions inside one course**, and versions can store their answers in
completely different structures.

Measured in Living on the Edge: `fill-in-the-blanks` **v1, v2, v3** (plus 7 instances with no
version in the URL), `buttonwidget` v2/v4, `general-drag-drop` v5/v6, `order-list` v5,
`matching` v2, `grouping` v1, `hotspot` v2, `carousel` v1.

Concretely — fill-in-the-blanks:

| Version | Answer location |
|---|---|
| v2 | `Config JSON` → `richEditableText` → `DropDownField{ options, correctIndex }` |
| v3 | `Configuration` → `dropdowns{ <uuid>: { correct: "optionN", options: {…} } }` |

Never assume one shape per family. Check the version before extracting.

### Grading mode

A family can grade in more than one way. `general-drag-drop` in Living on the Edge:

| Mode | Expected placement lives in | Activities |
|---|---|---|
| A | the config — items' `correctParent` | 5 |
| B | **the rule itself** — `Item Location JSON equal {…}` | 4 |
| ungraded | nowhere — free placement, no correct rule references the widget | 1 |

Absence from the config does not mean absence of an answer.

---

## Interaction family

The unit the driver keys on: a kind of interaction that needs one strategy for *detecting,
answering, and proving*. Spans both levels — a family is either a native
[part](#part) type (`janus-mcq`, `janus-dropdown`, `janus-multi-line-text`, `janus-slider`,
`janus-input-number`) or a CAPI [widget](#widget) (`fill-in-the-blanks`, `matching`, …).

Roughly 14 families exist in LotE; the driver currently handles 9. **A family the registry does
not implement must fail loudly by name** — never be walked past as though the screen had no
interaction.

Non-answering families (`buttonwidget`, `timer`, `carousel`, `image-scrub`) matter too: the role
classifier must not treat a screen as gradeable merely because it contains an iframe.

---

### Interaction family support matrix

The canonical table of what the driver can handle, kept in the `torus-adaptive-playwright` skill.
Two axes — **drive** (can we make the answer register?) and **derive** (can we read the correct
answer from the archive?) — and three states:

- **verified** — driven live and server-confirmed in a strict run
- **unverified** — code exists and the lesson completes, but no evidence the widget registered
- **unimplemented** — no driver code

`unverified` is the dangerous state: fill-in-the-blanks sat in it while submitting empty answers on
every run.

## Driver vocabulary

### Course map

Per-screen record of **what a course requires**: [screen](#activity) id, order,
[role](#role), interaction family, and the authored correct answer. Derivable from the archive;
contains no selectors and no click strategies. Private (course IP + answer keys), stored in the
Playwright assets bucket.

Currently hand-authored and called the *manifest*; the term *map* is used when discussing the
generated form.

### Widget-family registry

Per-family record of **how an interaction behaves**: how to tell it is ready, how to answer it,
how to prove the answer registered, and where its state lands. Written once, lives in the repo,
identical for every course. Never generated.

### Role

Classification of a [screen](#activity), derived from its part inventory and rules:

- **graded** — has an answerable interaction and rules that can mark it correct
- **content** — no answerable interaction; still submits an evaluation in delivery mode
- **navigation** — advanced by a widget's own control (e.g. `buttonwidget`), not the deck footer

### Receipt

Proof produced when a screen is answered: which directive answered it, the readback that confirmed
the widget registered it, and the **canonical expected submission** — the `stage.<partId>.<key>`
paths and values that must appear in the evaluation request body.

### Ledger

The per-screen record the strict walk accumulates and asserts at the end: identity, role, receipt,
evaluation count, verdict, payload match, transition. Printed redacted on failure — identifiers
and counts, never answer values.

### Screen identity

`model.id` (the archive's `custom.sequenceId`) is the stable identity. `model.resourceId` is the
live activity id — **course import remaps activity ids**, so the archive's `activity_id` is valid
for offline validation only; at runtime the walk enforces run-internal consistency instead.

### Attempt

A server-side activity attempt, identified by `attemptGuid`. The deck creates a fresh attempt
**only when a check comes back incorrect**, the response does not navigate to a different screen,
and the activity has attempts remaining (`triggerCheck.ts:424`) — *not* after every evaluation.
A screen answered correctly therefore keeps its attempt; a screen answered wrong then right
legitimately spans two GUIDs. Traffic
is therefore attributed to a screen by the `<sequenceId>|` prefix of its submitted part paths, not
by GUID.

### Evaluation

`PUT /state/course/<section>/activity_attempt/<guid>` — carries `partInputs`, returns
`actions.correct`. **The only place a verdict exists**; it is not persisted, so it must be captured
as it happens. Distinct from the deferred **save** (`PATCH …/active`), which persists part state
and uses a different body shape.

---

## Related

- [`testing-model-four-pieces.md`](./testing-model-four-pieces.md) — the mental model: map, registry, driver, oracle, and what belongs in each
- [`lesson-completion-is-not-an-oracle.md`](./lesson-completion-is-not-an-oracle.md) — why reaching the last screen proves nothing
