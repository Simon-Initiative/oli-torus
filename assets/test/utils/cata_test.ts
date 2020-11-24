import { Actions } from 'components/activities/check_all_that_apply/actions';
import * as ContentModel from 'data/content/model';
import produce from 'immer';
import { CheckAllThatApplyModelSchema } from 'components/activities/check_all_that_apply/schema'
import { createMatchRule, createRuleForIds, defaultCATAModel, getChoiceIds, getCorrectResponse,
  getIncorrectResponse, getResponseId, getResponses, getTargetedResponses,
  invertRule, unionRules,
} from 'components/activities/check_all_that_apply/utils';

const applyAction = (
  model: CheckAllThatApplyModelSchema,
  action: any) => {

  return produce(model, draftState => action(draftState));
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

function testResponse(text: string, rule: string, score: number = 0) {
  return {
    id: Math.random() + '',
    feedback: testFromText(text),
    rule,
    score,
  };
}

const testDefaultModel = defaultCATAModel;

describe('check all that apply question', () => {
  const model = testDefaultModel();

  it('can switch from simple to targeted feedback mode', () => {
    expect(model.type).toBe('SimpleCATA');
    const toggled = applyAction(model, Actions.toggleType());
    expect(toggled).toMatchObject({ type: 'TargetedCATA' });
    expect(toggled.authoring.targeted).toBeInstanceOf(Array);
    expect(toggled.authoring.targeted).toHaveLength(0);
  });

  it('can switch from targeted to simple feedback mode', () => {
    const toggled = applyAction(model, Actions.toggleType());
    const toggledBack = applyAction(toggled, Actions.toggleType());
    expect(toggledBack).toMatchObject({ type: 'SimpleCATA' });
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
    const withChoiceAdded = applyAction(model, Actions.addChoice());
    expect(withChoiceAdded.choices.length).toBeGreaterThan(model.choices.length);
    expect(getChoiceIds(withChoiceAdded.authoring.incorrect)).toHaveLength(2);
    expect(getChoiceIds(withChoiceAdded.authoring.correct)).toHaveLength(1);
  });

  it('can toggle choice correctness', () => {
    // First choice is correct
    const firstChoice = model.choices[0];
    const modelWithFirstChoiceToggled = applyAction(
      model, Actions.toggleChoiceCorrectness(firstChoice.id));
    expect(getChoiceIds(modelWithFirstChoiceToggled.authoring.correct))
      .not.toContain(firstChoice.id);
    expect(getChoiceIds(modelWithFirstChoiceToggled.authoring.incorrect))
      .toContain(firstChoice.id);
  });

  it('can edit a choice', () => {
    const newChoiceContent = testFromText('new content').content;
    const firstChoice = model.choices[0];
    expect(applyAction(model, Actions.editChoiceContent(firstChoice.id, newChoiceContent)).choices[0])
      .toHaveProperty('content', newChoiceContent);
  });

  it('can remove a choice from simple CATA', () => {
    const firstChoice = model.choices[0];
    const newModel = applyAction(model, Actions.removeChoice(firstChoice.id));
    expect(newModel.choices).toHaveLength(1);
    expect(getChoiceIds(newModel.authoring.correct)).not.toContain(firstChoice);
    expect(getChoiceIds(newModel.authoring.incorrect)).not.toContain(firstChoice);
  });

  it('can remove a choice from targeted CATA responses', () => {
    const firstChoice = model.choices[0];
    const toggled = applyAction(model, Actions.toggleType());
    const newModel = applyAction(toggled, Actions.removeChoice(firstChoice.id));
    newModel.authoring.targeted.forEach((assoc: any) => {
      expect(getChoiceIds(assoc)).not.toContain(firstChoice.id);
    })
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
    expect(createMatchRule('id')).toBe(`input like {id}`);
  });

  it('can invert rules', () => {
    expect(invertRule(createMatchRule('id'))).toBe(`!(input like {id})`);
  });

  it('can union rules', () => {
    expect(unionRules([createMatchRule('id1'), invertRule(createMatchRule('id2'))]))
      .toBe('input like {id1} && !(input like {id2})');
  });

  it('can create rules to match certain ids and not match others', () => {
    const toMatch = ['id1', 'id2'];
    const notToMatch = ['id3'];
    expect(createRuleForIds(toMatch, notToMatch))
      .toEqual('input like {id1} && input like {id2} && !(input like {id3})');
  });

  it('has at least 3 hints', () => {
    expect(model.authoring.parts[0].hints.length).toBeGreaterThanOrEqual(3);
  });

  it('can add a cognitive hint before the end of the array', () => {
    expect(applyAction(model, Actions.addHint()).authoring.parts[0].hints.length)
      .toBeGreaterThan(model.authoring.parts[0].hints.length);
  });

  it('can edit a hint', () => {
    const newHintContent = testFromText('new content').content;
    const firstHint = model.authoring.parts[0].hints[0];
    expect(applyAction(model,
      Actions.editHint(firstHint.id, newHintContent)).authoring.parts[0].hints[0])
      .toHaveProperty('content', newHintContent);
  });

  it('can remove a hint', () => {
    const firstHint = model.authoring.parts[0].hints[0];
    expect(applyAction(model,
      Actions.removeHint(firstHint.id)).authoring.parts[0].hints).toHaveLength(2);
  });

});
