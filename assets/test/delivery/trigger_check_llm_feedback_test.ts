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
});
