import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { getChoices } from 'components/activities/common/choices/authoring/choiceUtils';
import { makeChoice } from 'components/activities/types';
import { applyTestAction } from 'utils/test_utils';

describe('choices actions', () => {
  const model = {
    choices: [makeChoice('a'), makeChoice('b')],
  };
  it('can add a choice', () => {
    const newChoice = makeChoice('c');
    const newModel = applyTestAction(model, ChoiceActions.addChoice(newChoice));
    expect(newModel.choices).toHaveLength(3);
    expect(getChoices(newModel)[getChoices(newModel).length - 1].content).toEqual(
      newChoice.content,
    );
  });

  it('can edit a choice', () => {
    const newChoice = makeChoice('');
    const firstChoice = model.choices[0];
    expect(model.choices[0]).not.toHaveProperty('content', newChoice.content);
    expect(
      applyTestAction(model, ChoiceActions.editChoiceContent(firstChoice.id, newChoice.content))
        .choices[0],
    ).toHaveProperty('content', newChoice.content);
  });

  it('can set all choices', () => {
    const choice1 = makeChoice('1');
    const choice2 = makeChoice('2');
    expect(model.choices[0]).not.toHaveProperty('content', choice1.content);
    expect(model.choices[1]).not.toHaveProperty('content', choice2.content);

    const newModel = applyTestAction(model, ChoiceActions.setAllChoices([choice1, choice2]));
    expect(newModel.choices).toHaveLength(2);
    expect(newModel.choices[0]).toHaveProperty('content', choice1.content);
    expect(newModel.choices[1]).toHaveProperty('content', choice2.content);
  });

  it('can remove a choice', () => {
    expect(model.choices).toHaveLength(2);
    const choice1 = getChoices(model)[0];
    const newModel = applyTestAction(model, ChoiceActions.removeChoice(choice1.id));
    expect(newModel.choices).not.toContain(choice1);
    expect(newModel.choices).toHaveLength(1);
  });
});
