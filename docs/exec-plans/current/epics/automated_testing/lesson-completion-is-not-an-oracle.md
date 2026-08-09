# Why "the lesson reached its end" does not prove the lesson was answered correctly

**Status:** settled with evidence, 2026-07-31
**Context:** MER-5674 (Adaptive Lesson: LotE — Plate Tectonics, Playwright). Applies equally to
MER-5672 (greenhouse) and MER-5673 (d-orbitals), which share the driver.
**Audience:** anyone reviewing adaptive-lesson Playwright coverage, or deciding what an adaptive
happy-path test should assert.
**Vocabulary:** [Page](./adaptive-lesson-terminology.md#page), [Activity (= screen)](./adaptive-lesson-terminology.md#activity),
[Part](./adaptive-lesson-terminology.md#part), [Widget](./adaptive-lesson-terminology.md#widget), [Evaluation](./adaptive-lesson-terminology.md#evaluation) —
see [`adaptive-lesson-terminology.md`](./adaptive-lesson-terminology.md).

## The question

> If a Playwright test walks an adaptive lesson and reaches the last screen, hasn't it already
> proven what the ticket asks for? Surely the only way to reach the end is to complete every
> screen correctly.

It is a reasonable intuition — adaptive lessons *feel* gated. It is also false for these lessons,
and the gap is not theoretical: it is the defect this ticket was opened to fix.

## Three independent disproofs

### 1. Measured — four screens were never answered, and the lesson still ended

Recon runs against the real Plate Tectonics lesson (22 [screens](./adaptive-lesson-terminology.md#activity), real server, real course archive)
reached the lesson's end state with **4 screens never answered**: two drag-and-drops (Heat and
Pressure in Earth's Asthenosphere, Earth's Convection) and two fill-in-the-blanks (Check In, Put
it all Together). No drag placements and no widget fills were recorded for them in the run logs.
The test asserted completion text and **passed**.

### 2. Measured — every fill-in-the-blank submission was empty, on every historical run

Captured from the evaluation request bodies (`PUT /state/course/<section>/activity_attempt/<guid>`):
every fill-in-the-blank submission carried `Inputs.drop-N.Selected Index: -1` for every blank —
i.e. nothing selected. The server graded them `correct: false`. Runs completed regardless.

Root cause (fixed in this ticket): the [widget](./adaptive-lesson-terminology.md#widget) wraps each `<select>` in a jQuery-UI *selectmenu*.
Setting the native element programmatically and dispatching `input`/`change` updates the DOM but
never the widget's model, so the value never reached CAPI. The fill *looked* successful to the
old driver and was invisible in the submitted payload.

### 3. Structural — three screens are authored to advance after a wrong answer

Counted directly in the course archive (`397294.json` → each activity's
`content.authoring.rules`), the number of **incorrect**-answer rules whose event actions include
a `navigation` action:

| Screen | Wrong-answer rules that navigate |
|---|---|
| Earth's Layers and Their Behavior (matching) | 1 |
| Heat and Pressure in Earth's Asthenosphere (drag-drop) | 1 |
| Earth's Convection (drag-drop) | 1 |
| the other 19 screens | 0 |

Reproduce:

```bash
# from an unpacked course archive directory
python3 - <<'EOF'
import json
page = json.load(open('397294.json'))
for k in page['content']['model'][0]['children']:
    a = json.load(open(f"{k['activity_id']}.json"))
    rules = a['content'].get('authoring', {}).get('rules', [])
    wrong_nav = sum(
        1
        for r in rules if not r.get('correct')
        for ev in r.get('event', {}).get('params', {}).get('actions', [])
        if ev.get('type') == 'navigation'
    )
    print(f"{k['custom'].get('sequenceName',''):40} rules={len(rules):>3} wrong-nav={wrong_nav}")
EOF
```

Those three are legitimate pedagogical choices by the course author — "let the student move on
after a mistake" is a normal design. They simply make completion an unsound proxy for correctness.

## Where the intuition is partly right

On the other 19 screens, an incorrect answer does not navigate, so a naive walk cannot trivially
breeze through them. "Reached the end" is not a *zero*-information signal. But it is a weak,
indirect one, and it fails in four ways that matter:

1. **It conflates three different outcomes** — answered correctly, answered incorrectly on a
   screen authored to let you pass, and never answered at all. That is exactly how four skipped
   screens went unnoticed across every run.
2. **It has no diagnostic value.** It reports that the lesson ended, not which screen failed or
   why. Debugging starts from zero.
3. **It depends on course authoring, not on test logic.** A future content edit that adds a
   bypass rule silently weakens the test, with no signal to anyone. A test's guarantee should not
   be a side effect of someone else's content decisions.
4. **It is not what the ticket asks.** A *happy path* test claims a student can complete the
   lesson correctly. "The deck let me through" is a different, weaker statement.

The deeper risk: a green test that cannot fail is worse than no test. Without a test, everyone
knows the lesson needs manual QA. With a green one, people stop checking — the green light
suppresses the scrutiny that would have caught the regression.

## What the strict driver asserts instead

Per screen, in a ledger checked at the end of the run:

- every screen the manifest declares was visited, **in order**, exactly once (22/22);
- the answer **registered in the widget** (read back from the widget's own state, not the DOM we
  poked);
- the **submitted network payload** contains the intended answer (path + value correlation against
  the answer key, not mere presence);
- the **server's own verdict** for that screen is `actions.correct === true` — the only place
  "correct" exists, and it is not persisted, so it must be captured as it happens;
- **exactly one submission** per screen (two only when the deck's own feedback-acknowledgement
  legally re-checks), all belonging to the attempt the screen rendered;
- the transition taken matches the one the evaluation response dictated.

## The demonstration that settles it

A **canary run**: the same lesson, same driver, with a single answer deliberately replaced by a
wrong one in the key.

- Old-style assertion (completion text visible): would have **passed**.
- Strict ledger: **failed at exactly that screen**, naming it, with `verdict=false`.

That is the difference between a test that can fail for the reason it exists and one that cannot.

## Related

- `mer-5674-driver-decision.md` — §2 (what the old driver could not detect), §4 (options and
  dominance arguments), the CODEX REVIEW ROUND 1/2 sections, and the full catalogue of defects the
  strict oracle surfaced.
- `mer-5674-followups.md` — FU-2 (a rules-worker error path returning 500) was found by these runs.
