import { IAdaptiveRule, IEvent } from 'apps/delivery/store/features/activities/slice';
import {
  checkResultHasLLMFeedbackAction,
  hasPotentialLLMFeedbackRule,
} from 'apps/delivery/store/features/adaptivity/actions/triggerCheck';

describe('triggerCheck LLM feedback helpers', () => {
  it('detects rules that can produce AI-generated feedback', () => {
    const rules: IAdaptiveRule[] = [
      {
        id: 'rule-1',
        name: 'Rule 1',
        priority: 0,
        correct: false,
        default: false,
        disabled: false,
        conditions: {},
        event: {
          type: 'rule-1',
          params: {
            actions: [
              {
                type: 'activationPoint',
                params: {
                  kind: 'feedback',
                  prompt: 'Guide the student without revealing the answer.',
                },
              },
            ],
          },
        },
      },
    ];

    expect(hasPotentialLLMFeedbackRule(rules)).toBe(true);
  });

  it('detects triggered AI-generated feedback actions in rule results', () => {
    const results: IEvent[] = [
      {
        type: 'event-1',
        params: {
          actions: [
            {
              type: 'activationPoint',
              params: { kind: 'feedback', prompt: 'Offer a hint based on the response.' },
            },
          ],
        },
      },
    ];

    expect(checkResultHasLLMFeedbackAction(results)).toBe(true);
  });

  it('ignores malformed activation-point actions without throwing', () => {
    const malformedResults = [
      {
        params: {
          actions: [{ type: 'activationPoint' }],
        },
      },
    ];

    expect(() =>
      checkResultHasLLMFeedbackAction(malformedResults as unknown as IEvent[]),
    ).not.toThrow();
    expect(checkResultHasLLMFeedbackAction(malformedResults as unknown as IEvent[])).toBe(false);
  });

  it('requires an explicit feedback kind for AI-generated feedback detection', () => {
    const legacyPromptOnlyRules: IAdaptiveRule[] = [
      {
        id: 'rule-legacy',
        name: 'Legacy Rule',
        priority: 0,
        correct: false,
        default: false,
        disabled: false,
        conditions: {},
        event: {
          type: 'rule-legacy',
          params: {
            actions: [
              {
                type: 'activationPoint',
                params: {
                  prompt: 'This prompt belongs to a legacy DOT trigger.',
                },
              },
            ],
          },
        },
      },
    ];

    expect(hasPotentialLLMFeedbackRule(legacyPromptOnlyRules)).toBe(false);
  });
});
