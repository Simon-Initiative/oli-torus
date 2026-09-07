import { isExperimentStrategy } from 'components/content/add_resource_content/NonActivities';

describe('isExperimentStrategy', () => {
  it('accepts canonical and legacy experiment-controlled strategies', () => {
    expect(isExperimentStrategy('experiment_controlled')).toBe(true);
    expect(isExperimentStrategy('upgrade_decision_point')).toBe(true);
  });

  it('keeps learner-choice groups out of experiment insertion', () => {
    expect(isExperimentStrategy('user_section_preference')).toBe(false);
  });
});
