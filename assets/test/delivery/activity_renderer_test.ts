import { checkResultsHaveNavigation } from '../../src/apps/delivery/components/checkResults';
import { CheckResults } from '../../src/apps/delivery/store/features/adaptivity/slice';

const currentActivityTree = [
  {
    content: {
      custom: {
        combineFeedback: false,
      },
    },
  },
];

const buildCheckResults = (actions: any[]): CheckResults => ({
  timestamp: 1,
  results: [
    {
      params: {
        actions,
      },
    },
  ],
  attempt: null,
  correct: false,
  score: 0,
  outOf: 0,
});

describe('checkResultsHaveNavigation', () => {
  it('ignores activation point actions while checking for navigation', () => {
    const checkResults = buildCheckResults([
      {
        type: 'activationPoint',
        params: {
          prompt: 'Help the learner recover from this trap state.',
        },
      },
    ]);

    expect(checkResultsHaveNavigation(checkResults, currentActivityTree, 'screen-1')).toBe(false);
  });

  it('still detects navigation when an activation point is present in the same result', () => {
    const checkResults = buildCheckResults([
      {
        type: 'activationPoint',
        params: {
          prompt: 'Help the learner recover from this trap state.',
        },
      },
      {
        type: 'navigation',
        params: {
          target: 'screen-2',
        },
      },
    ]);

    expect(checkResultsHaveNavigation(checkResults, currentActivityTree, 'screen-1')).toBe(true);
  });
});
