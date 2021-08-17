import { makeChoice } from 'components/activities/types';
import { defaultMCModel } from 'components/activities/multiple_choice/utils';
import { dispatch } from 'utils/test_utils';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { MCActions } from 'components/activities/common/authoring/actions/multipleChoiceActions';

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
    expect(dispatch(model, ChoiceActions.addChoice(makeChoice(''))).choices.length).toBeGreaterThan(
      model.choices.length,
    );
  });

  it('can edit a choice', () => {
    const newChoiceContent = makeChoice('new content').content;
    const firstChoice = model.choices[0];
    expect(
      dispatch(model, ChoiceActions.editChoiceContent(firstChoice.id, newChoiceContent)).choices[0],
    ).toHaveProperty('content', newChoiceContent);
  });

  it('can remove a choice', () => {
    const firstChoice = model.choices[0];
    const newModel = dispatch(model, MCActions.removeChoice(firstChoice.id));
    expect(newModel.choices).toHaveLength(1);
    expect(newModel.authoring.parts[0].responses).toHaveLength(2);
  });

  it('has the same number of responses as choices', () => {
    expect(model.choices.length).toEqual(model.authoring.parts[0].responses.length);
  });

  it('has at least 3 hints', () => {
    expect(model.authoring.parts[0].hints.length).toBeGreaterThanOrEqual(3);
  });
});
