/**
 * ONE pure transition derivation (spec §3.1): the driver consults it online,
 * the oracle replays it offline — the seam that previously duplicated
 * transition judgement is gone by construction.
 *
 * NORMATIVE SOURCE is the deck footer itself (DeckLayoutFooter.tsx):
 * - event selection for `combine_feedback` mirrors lines 420-444 EXACTLY —
 *   ALL results when every result carries the same single navigation target;
 *   otherwise FIRST result only when the first event navigates AND the
 *   aggregate verdict (`every result correct`) is false; otherwise ALL.
 *   `combine_feedback: false` processes `results[0]` alone.
 * - flattening mirrors `processResults` (203-219); the FIRST navigation
 *   action's target wins (568-575).
 * - feedback (rule-driven or server LLM text, 546-558) queues navigation and
 *   acknowledges with one click (565-571); an ack with no queued target
 *   legally re-checks (679-681).
 * - navigation without feedback auto-navigates; `endOfLesson` is terminal
 *   (589-591 → finalizeLesson).
 *
 * Plan kinds map to the spec's names: auto-navigate = await-navigation,
 * feedback+navigate ack = ack-feedback, feedback+recheck ack =
 * expect-recheck, terminal = terminal. `none` is derived honestly here and
 * judged illegal by the oracle (§3.5: `none` is not a legal post-check plan).
 */

export type TransitionAction = { type: string; params?: Record<string, unknown> };

export type CheckResultEvent = {
  params?: {
    correct?: boolean;
    actions?: TransitionAction[];
  };
};

export type PlannedTransition =
  | { kind: 'auto-navigate'; target: string }
  | { kind: 'terminal' }
  | { kind: 'feedback'; ack: { kind: 'navigate'; target: string } | { kind: 'recheck' } }
  | { kind: 'none' };

const navigationActions = (event: CheckResultEvent): TransitionAction[] =>
  (event.params?.actions ?? []).filter((a) => a.type === 'navigation');

/** DeckLayoutFooter.tsx:307-323 — every result navigates, one distinct target. */
function allEventsShareOneNavigation(results: CheckResultEvent[]): boolean {
  const targets = new Set<string>();
  let navigatingResults = 0;
  for (const result of results) {
    const navs = navigationActions(result);
    if (navs.length > 0) navigatingResults += 1;
    for (const nav of navs) targets.add(String(nav.params?.target ?? ''));
  }
  return navigatingResults === results.length && targets.size === 1;
}

/** DeckLayoutFooter.tsx:420-444, the exact selection algorithm — all four branches. */
export function selectProcessedEvents(
  results: CheckResultEvent[],
  combineFeedback: boolean,
): CheckResultEvent[] {
  if (results.length === 0) return [];
  if (!combineFeedback) return [results[0]];
  if (allEventsShareOneNavigation(results)) return results;
  const isCorrect = results.every((r) => !!r.params?.correct);
  if (navigationActions(results[0]).length > 0 && !isCorrect) return [results[0]];
  return results;
}

export function planTransition(
  results: CheckResultEvent[],
  llmFeedback: { text?: string } | null | undefined,
  combineFeedback: boolean,
): PlannedTransition {
  const events = selectProcessedEvents(results, combineFeedback);
  const actions = events.flatMap((e) => e.params?.actions ?? []);
  const feedback = actions.filter((a) => a.type === 'feedback');
  const navigation = actions.filter((a) => a.type === 'navigation');
  const target = navigation.length > 0 ? String(navigation[0].params?.target ?? '') : '';

  if (feedback.length > 0 || llmFeedback?.text) {
    return {
      kind: 'feedback',
      ack: navigation.length > 0 ? { kind: 'navigate', target } : { kind: 'recheck' },
    };
  }
  if (navigation.length > 0) {
    return target === 'endOfLesson' ? { kind: 'terminal' } : { kind: 'auto-navigate', target };
  }
  return { kind: 'none' };
}

export function transitionNavigates(plan: PlannedTransition): boolean {
  return (
    plan.kind === 'auto-navigate' ||
    plan.kind === 'terminal' ||
    (plan.kind === 'feedback' && plan.ack.kind === 'navigate')
  );
}
