import { effectiveAdaptiveScreenMaxScore } from '../../src/apps/authoring/utils/adaptiveScoring';

const adaptiveActivity = (maxScore: unknown) => ({
  content: {
    custom: { maxScore },
    partsLayout: [{ id: 'dropdown_1', type: 'janus-dropdown' }],
  },
});

describe('adaptive scoring helpers', () => {
  it('preserves an explicitly unscored adaptive screen with scorable inputs', () => {
    const activity = adaptiveActivity(0);

    expect(effectiveAdaptiveScreenMaxScore(activity)).toBe(0);
  });

  it('preserves positive authored scores for adaptive screens with scorable inputs', () => {
    const activity = adaptiveActivity(2);

    expect(effectiveAdaptiveScreenMaxScore(activity)).toBe(2);
  });

  it('does not infer a score for adaptive screens with scorable inputs and no authored score', () => {
    const activity = adaptiveActivity(undefined);

    expect(effectiveAdaptiveScreenMaxScore(activity)).toBe(0);
  });
});
