import { Actions } from 'components/activities/ordering/actions';
import * as ContentModel from 'data/content/model';
import produce from 'immer';
import { OrderingModelSchema } from 'components/activities/ordering/schema';
import {
  canMoveChoiceUp, canMoveChoiceDown, createMatchRule, createRuleForIds,
  defaultOrderingModel, getChoiceIds, getCorrectResponse,
  getHints, getTargetedChoiceIds,
  getIncorrectResponse, getResponseId, getResponses, getTargetedResponses,
  invertRule, unionRules, getCorrectOrdering,
} from 'components/activities/ordering/utils';
import { Choice } from 'components/activities/types';

const applyAction = (
  model: OrderingModelSchema,
  action: any) => {

  return produce(model, draftState => action(draftState, () => { return; }));
};

function testFromText(text: string) {
  return {
    id: Math.random() + '',
    content: {
      model: [
        ContentModel.create<ContentModel.Paragraph>({
          type: 'p',
          children: [{ text }],
          id: Math.random() + '',
        }),
      ],
      selection: null,
    },
  };
}


// Can move choice up
// Move choice up
// Can move choice down
// Move choice down
// Correct and incorrect feedback should have length === choices.length

const testDefaultModel = defaultOrderingModel;

describe('ordering question', () => {
  const model = testDefaultModel();

  it('can move a choice up in authoring', () => {
    const firstChoice = model.choices[0];
    const lastChoice = model.choices[model.choices.length - 1];

    expect(canMoveChoiceUp(model, firstChoice.id)).toBe(false);
    expect(canMoveChoiceUp(model, lastChoice.id)).toBe(true);

    const firstMovedUp = applyAction(model, Actions.moveChoice('up', firstChoice.id));
    expect(model.choices.findIndex(c => c === lastChoice))
      .toEqual(firstMovedUp.choices.findIndex((c: Choice) => c === lastChoice));

    const lastMovedUp = applyAction(model, Actions.moveChoice('up', lastChoice.id));
    expect(lastMovedUp.choices[lastMovedUp.choices.length - 2]).toBe(lastChoice);
  });

  it('can move a choice down in authoring', () => {
    const firstChoice = model.choices[0];
    const lastChoice = model.choices[model.choices.length - 1];

    expect(canMoveChoiceDown(model, firstChoice.id)).toBe(true);
    expect(canMoveChoiceDown(model, lastChoice.id)).toBe(false);

    const firstMovedDown = applyAction(model, Actions.moveChoice('down', firstChoice.id));
    expect(firstMovedDown.choices[1]).toBe(firstChoice);

    const lastMovedDown = applyAction(model, Actions.moveChoice('down', lastChoice.id));
    expect(model.choices.findIndex(c => c === lastChoice))
      .toEqual(lastMovedDown.choices.findIndex((c: Choice) => c === lastChoice));
  });

  it('has correct feedback that correspond to all choices', () => {
    expect(getCorrectOrdering(model)).toHaveLength(model.choices.length);
    const toggled = applyAction(model, Actions.toggleType());
    expect(getTargetedChoiceIds(toggled)).toHaveLength(0);
  });

  it('can switch from simple to targeted feedback mode', () => {
    expect(model.type).toBe('SimpleOrdering');
    const toggled = applyAction(model, Actions.toggleType());
    expect(toggled).toMatchObject({ type: 'TargetedOrdering' });
    expect(toggled.authoring.targeted).toBeInstanceOf(Array);
    expect(toggled.authoring.targeted).toHaveLength(0);
  });

  it('can switch from targeted to simple feedback mode', () => {
    const toggled = applyAction(model, Actions.toggleType());
    const toggledBack = applyAction(toggled, Actions.toggleType());
    expect(toggledBack).toMatchObject({ type: 'SimpleOrdering' });
    expect(toggledBack.authoring).not.toHaveProperty('targeted');
  });

  it('has a stem', () => {
    expect(model).toHaveProperty('stem');
  });

  it('can edit stem', () => {
    const newStemContent = testFromText('new content').content;
    expect(applyAction(model, Actions.editStem(newStemContent)).stem).toMatchObject({
      content: newStemContent,
    });
  });

  it('has at least one choice', () => {
    expect(model).toHaveProperty('choices');
    expect(model.choices.length).toBeGreaterThan(0);
  });

  it('can add a choice', () => {
    // default model has 2 choices
    const withChoiceAdded = applyAction(model, Actions.addChoice());
    expect(withChoiceAdded.choices.length).toBeGreaterThan(model.choices.length);
    expect(getChoiceIds(withChoiceAdded.authoring.correct)).toHaveLength(3);
  });

  it('can edit a choice', () => {
    const newChoiceContent = testFromText('new content').content;
    const firstChoice = model.choices[0];
    expect(applyAction(model, Actions.editChoiceContent(firstChoice.id, newChoiceContent))
      .choices[0])
      .toHaveProperty('content', newChoiceContent);
  });

  it('can remove a choice from simple Ordering', () => {
    const firstChoice = model.choices[0];
    const newModel = applyAction(model, Actions.removeChoice(firstChoice.id));
    expect(newModel.choices).toHaveLength(1);
    expect(getChoiceIds(newModel.authoring.correct)).not.toContain(firstChoice);
  });

  it('can remove a choice from targeted Ordering responses', () => {
    const firstChoice = model.choices[0];
    const toggled = applyAction(model, Actions.toggleType());
    const newModel = applyAction(toggled, Actions.removeChoice(firstChoice.id));
    newModel.authoring.targeted.forEach((assoc: any) => {
      expect(getChoiceIds(assoc)).not.toContain(firstChoice.id);
    });
  });

  it('has one correct response', () => {
    expect(getCorrectResponse(model)).toBeTruthy();
  });

  it('has one incorrect response', () => {
    expect(getIncorrectResponse(model)).toBeTruthy();
  });

  it('can edit feedback', () => {
    const newFeedbackContent = testFromText('new content').content;
    const firstResponse = model.authoring.parts[0].responses[0];
    expect(applyAction(model, Actions.editResponseFeedback(firstResponse.id, newFeedbackContent))
      .authoring.parts[0].responses[0].feedback)
      .toHaveProperty('content', newFeedbackContent);
  });

  it('can add a targeted feedback in targeted mode', () => {
    expect(applyAction(model, Actions.addTargetedFeedback())).toEqual(model);
    const toggled = applyAction(model, Actions.toggleType());
    const withNewResponse = applyAction(toggled, Actions.addTargetedFeedback());
    expect(getResponses(withNewResponse).length).toBeGreaterThan(getResponses(model).length);
    expect(withNewResponse.authoring.targeted.length).toBe(1);
    expect(getChoiceIds(withNewResponse.authoring.targeted[0])).toHaveLength(0);
  });

  it('can remove a targeted feedback in targeted mode', () => {
    expect(applyAction(model, Actions.removeTargetedFeedback('id'))).toEqual(model);
    const toggled = applyAction(model, Actions.toggleType());
    const withNewResponse = applyAction(toggled, Actions.addTargetedFeedback());
    const removed = applyAction(withNewResponse, Actions.removeTargetedFeedback(
      getResponseId(withNewResponse.authoring.targeted[0])));
    expect(getResponses(removed)).toHaveLength(2);
    expect(getTargetedResponses(removed)).toHaveLength(0);
  });

  it('can create a match rule', () => {
    expect(createMatchRule('id')).toBe('input like {id}');
  });

  it('can invert rules', () => {
    expect(invertRule(createMatchRule('id'))).toBe('(!(input like {id}))');
  });

  it('can union rules', () => {
    expect(unionRules([createMatchRule('id1'), invertRule(createMatchRule('id2'))]))
      .toBe('(!(input like {id2})) && (input like {id1})');
  });

  it('can create rules to to match choice orderings', () => {
    const ordering1 = ['id1', 'id2', 'id3'];
    const ordering2 = ['id3', 'id2', 'id1'];
    expect(createRuleForIds(ordering1)).toEqual('input like {id1 id2 id3}');
    expect(createRuleForIds(ordering2)).toEqual('input like {id3 id2 id1}');
  });

  it('has at least 3 hints', () => {
    expect(getHints(model).length).toBeGreaterThanOrEqual(3);
  });

  it('can add a cognitive hint before the end of the array', () => {
    expect(getHints(applyAction(model, Actions.addHint())).length)
      .toBeGreaterThan(getHints(model).length);
  });

  it('can edit a hint', () => {
    const newHintContent = testFromText('new content').content;
    const firstHint = getHints(model)[0];
    expect(getHints(applyAction(model,
      Actions.editHint(firstHint.id, newHintContent)))[0])
      .toHaveProperty('content', newHintContent);
  });

  it('can remove a hint', () => {
    const firstHint = getHints(model)[0];
    expect(getHints(applyAction(model, Actions.removeHint(firstHint.id))))
      .toHaveLength(2);
  });

});
