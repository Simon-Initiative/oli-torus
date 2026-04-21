import {
  checkResultHasLLMFeedbackAction,
  hasPotentialLLMFeedbackRule,
} from 'apps/delivery/store/features/adaptivity/actions/triggerCheck';

describe('triggerCheck LLM feedback helpers', () => {
  it('detects rules that can produce AI-generated feedback', () => {
    const rules = [
      {
        event: {
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
    const results = [
      {
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
