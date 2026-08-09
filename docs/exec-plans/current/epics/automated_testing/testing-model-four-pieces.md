# The mental model: map, registry, driver, oracle

**Working notes.** The conceptual model behind the adaptive-lesson testing design, worked out in
conversation 2026-08-02. Companion to
[`adaptive-lesson-terminology.md`](./adaptive-lesson-terminology.md) (definitions) and
[`SESSION-FINDINGS-2026-07-31.md`](./SESSION-FINDINGS-2026-07-31.md) (discoveries).

---

## 1. The map is not the hierarchy

A natural first guess is that the map *is* the course tree. It isn't, in two ways.

**The map is derived from the tree, not equal to it.** The archive holds everything — text,
images, layout, styling, rules, media. The map is the thin extract a test needs: which screens, in
what order, what each requires. Ore versus refined metal.

**The map covers ONE page, not the project.** One adaptive page is one Playwright test, because
deck state accumulates and a run cannot start mid-lesson. So a map is a **flattened slice of one
branch** of the hierarchy:

```
COURSE ─ Living on the Edge
└─ UNIT ─ Geologic Risk               ← navigation only; the map does not model units
   └─ PAGE ─ Plate Tectonics          ← ONE page = ONE test = ONE map
      └─ 22 ACTIVITIES                ← flattened into the map's ordered entries
         └─ PARTS → WIDGETS           ← the map records family + answer, not selectors
```

Everything above the page is discarded. Everything below the part is delegated to the registry.

## 2. "Sequence" is right for our lesson, not in general

Measured on Plate Tectonics: **0 of 22 screens have a navigation target other than the next
screen.** Strictly linear, so an ordered list is a faithful model here.

It will not hold across the epic:

- **MER-5677** (Phases of the Moon) has selectable pathways — easy and hard — plus question banks
  and randomisation, so each run sees a different lesson.
- **MER-5671** (Designer Planet) has answers that depend on responses given on earlier screens.
- **MER-5670** (Our Blue Planet) wants a run that deliberately answers *wrong* first, to prove
  attempt-based scoring decrements — a different expected path through the same screens.

So the map's real concept is **the expected path through a page's screens**, which happens to be a
plain sequence for Plate Tectonics. Any schema that hard-codes linearity will need reworking for
three of the six lessons already in flight.

## 3. The four pieces

| Piece | Answers | Example | Changes when |
|---|---|---|---|
| **Map** | *What does this course require?* | "screen 3 is graded; blank `drop-1` = option 4" | course content changes |
| **Registry** | *How does this kind of interaction work?* | "fill-in-the-blanks: click `#id-button`, pick from the menu, verify `Selected Index ≥ 0`" | a new widget family appears |
| **Driver** | *Do it, in order* | walk screen 1 → 2 → 3, exactly one click each | almost never |
| **Oracle** | *Did it actually work?* | payload carried our answer; server returned `correct: true` | almost never |

A kitchen version of the same split:

- **Map** — the recipe for this dish: these ingredients, this order.
- **Registry** — knowing how a whisk, an oven, a blender each work.
- **Driver** — the cook, following the recipe, reaching for the right tool.
- **Oracle** — tasting at each step to confirm it actually worked.

The old test had **no oracle**: the cook followed the recipe, never tasted, and declared success
because dinner time arrived. Some ingredients were never added — the whisk sat in a drawer nobody
opened — and nothing caught it because nothing was tasted.

## 4. Why the split matters — evidence, not tidiness

*How a whisk works* is not recipe knowledge. It is the same for every dish. Today that knowledge
is copy-pasted into each lesson's code, and the consequence is measurable:

- **Santi** (MER-5672) hit it on the matching widget: *"now reports a clear error when it fails to
  link a pair, instead of silently continuing."*
- **We** hit it on fill-in-the-blanks: every submission carried `Selected Index: -1` on every
  historical run, because a jQuery-UI selectmenu ignores DOM events it did not originate.
- **Gastón's open PR #6750** contains the same `dispatchEvent(new Event('input'/'change'))`
  pattern (diff read, not run — a signal to raise, not a verdict).

Three engineers, independently, same failure mode: *the UI looks answered, the application never
heard it, the test passes.* That is not three mistakes. It is a property of driving CAPI widgets
that nobody can be expected to rediscover, and the argument for one registry is that this knowledge
must live in exactly one place or be lost again on the next lesson.

## 5. What is fused today, and where each piece should live

| Today | Should be |
|---|---|
| Map and registry fused in one private JSON (`kind: "frame_selects"`, `ready_selector: "#drop-1"` sit beside the answers) | Map holds course facts only; registry holds families, in the repo |
| Registry logic spread across `AdaptiveDeckPO` methods, `performDirective`, `savedSignalForDirective`, `expectedForDirective` | One module per family owning detect / ready / answer / readback / expected payload / barrier |
| Driver and oracle interleaved — the walk audits as it goes, then `assertLedger` audits again | Driver records evidence; one pure oracle judges it |
| Attribution decided by whichever per-screen observer is armed | One lesson-wide journal; attribution as a pure function over it |

The fusion is why review findings keep landing in seams: rounds 1–2 found defects in the build,
rounds 3–4 found defects in the fixes, and all seven round-4 findings trace to round-3 changes.

## 6. Consequences for the map's schema

Derived from the six lessons actually in flight, not from theory:

1. **Answers need four kinds**, not one:
   - *exact value* — extracted from the archive (MCQ from the correct rule, fill-in-the-blank from
     `Config JSON → correctIndex`)
   - **constraint** — the rule states a requirement rather than an answer. **Measured: 48 of 52
     free-text activities in this course grade on `textLength >= N` alone.** The map stores
     `minLength: 50`; the driver types conforming text; the receipt asserts the constraint. No
     invented sentence needs maintaining in a key.
   - *computed* — evaluated at runtime (MER-5675's parallax → distance → luminosity)
   - *manual* — genuinely needs a human. **Rarer than assumed:** only 4 activities in 557 check
     actual text content, and 3 of those state the required words in the rule
     (`containsAnyOf`, `contains`), leaving 1 exact-string case that the rule itself supplies.
2. **The expected verdict must be per-screen**, not globally "correct" — MER-5670 needs
   deliberately wrong first attempts.
3. **Paths can branch**, so the map cannot assume a fixed linear order for every lesson.
4. **Cross-screen dependencies exist** (MER-5671), so some answers are not knowable before the run.
5. **An unimplemented family must fail loudly by name** — `hotspot` (20 instances in LotE),
   `slider`, `input-number` and `image-scrub` are present and undriven today.
6. **The registry keys on family + VERSION, not family alone.** One course holds
   fill-in-the-blanks v1/v2/v3 whose answers live in different structures; buttonwidget v2/v4;
   drag-drop v5/v6. A registry entry that ignores the `/prod/N` in the widget URL will silently
   mis-drive a version it has never seen.
7. **A family can grade in several modes.** Drag-and-drop stores the expected placement in the
   config *or* in the rule. The map must record which mode a screen uses; absence from one
   location is not absence of an answer.
8. **Non-answering families must be represented**, not omitted — `buttonwidget`, `timer`,
   `carousel`, `image-scrub`, and probably `progress-bar` and `flashcard`. A screen is not
   gradeable merely because it contains an iframe.

## 6b. Scope actually agreed (2026-08-02)

Not every family in every course — **the three lessons whose archives are in our bucket**: Plate
Tectonics, Greenhouse Molecules, Dazzling d-Orbitals. Their union is 18 family+version entries,
6 of which are verified (all from Plate Tectonics' strict runs). See §3f of
`SESSION-FINDINGS-2026-07-31.md` for the per-family breakdown.

Bio Beyond, HW and Infiniscope archives are not in the bucket and belong to other engineers'
tickets. Do not build for their families until someone needs them.

## 7. What the generator does with all this

It reads *downward* through the hierarchy and writes *upward* into the map:

| Level read | Emits | Confidence |
|---|---|---|
| page file → `children[]` | ordered screen ids + resource ids | certain — transcription |
| activity → `partsLayout` + `rules` | role, interaction family | derivable by rule |
| CAPI part → `Config JSON` | fill-in-the-blank answers via `correctIndex` | certain — 5/5 screens |
| activity → correct rule | MCQ answer via `stage.<part>.selectedChoice equal N` | proved on 7 of 9 |
| janus-multi-line-text | the rule's own requirement — usually `textLength >= N` | constraint, derivable |
| multi-select MCQ | not yet — different rule encoding | `unsupported`, named |

It never emits a selector or a click strategy, because those belong to the registry. That is
precisely what makes the map generatable: **everything left in it exists in the archive.**

Validation is already available: generate against Plate Tectonics and diff the output against the
hand-authored map that produced six green runs. Agreement proves the tool; disagreement finds an
error in the tool *or* in the hand map — both worth knowing.

---

## Related

- [`adaptive-lesson-terminology.md`](./adaptive-lesson-terminology.md) — definitions and measured counts
- [`lesson-completion-is-not-an-oracle.md`](./lesson-completion-is-not-an-oracle.md) — why the old assertion was insufficient
- [`SESSION-FINDINGS-2026-07-31.md`](./SESSION-FINDINGS-2026-07-31.md) — the epic landscape and open decisions
- [`mer-5674-driver-decision.md`](./mer-5674-driver-decision.md) — the ticket's history and review rounds
