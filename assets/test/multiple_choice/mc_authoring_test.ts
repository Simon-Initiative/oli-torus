import { MCActions } from 'components/activities/multiple_choice/actions';
import { makeChoice } from 'components/activities/types';
import { defaultMCModel } from 'components/activities/multiple_choice/utils';
import { applyTestAction } from 'utils/test_utils';
import { getResponses } from 'components/activities/common/responses/authoring/responseUtils';
import { matchRule } from 'components/activities/common/responses/authoring/rules';

describe('multiple choice question', () => {
  const model = defaultMCModel();

  it('has a stem', () => {
    expect(model).toHaveProperty('stem');
  });

  it('has at least one choice', () => {
    expect(model).toHaveProperty('choices');
    expect(model.choices.length).toBeGreaterThan(0);
  });

  it('can add a choice', () => {
    const newChoice = makeChoice('');
    expect(applyTestAction(model, MCActions.addChoice(newChoice)).choices.length).toBeGreaterThan(
      model.choices.length,
    );
    expect(getResponses(model).find((r) => r.rule === matchRule(newChoice.id))).toBeTruthy();
  });

  it('can remove a choice', () => {
    const firstChoice = model.choices[0];
    const newModel = applyTestAction(model, MCActions.removeChoice(firstChoice.id));
    expect(newModel.choices).toHaveLength(1);
    expect(newModel.authoring.parts[0].responses).toHaveLength(1);
    expect(getResponses(model).find((r) => r.rule === matchRule(firstChoice.id))).toBeFalsy();
  });

  it('has the same number of responses as choices', () => {
    expect(model.choices.length).toEqual(model.authoring.parts[0].responses.length);
  });

  it('has at least 3 hints', () => {
    expect(model.authoring.parts[0].hints.length).toBeGreaterThanOrEqual(3);
  });
});
