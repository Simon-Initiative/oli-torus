import { CATAActions } from 'components/activities/check_all_that_apply/actions';
import * as ContentModel from 'data/content/model';
import produce from 'immer';
import {
  CheckAllThatApplyModelSchema,
  TargetedCATA,
} from 'components/activities/check_all_that_apply/schema';
import {
  defaultCATAModel,
  getChoiceIds,
  getCorrectResponse,
  getIncorrectResponse,
  getResponseId,
  getTargetedResponses,
} from 'components/activities/check_all_that_apply/utils';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { makeChoice, makeFeedback, makeHint, makeStem } from 'components/activities/types';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { HintActions } from 'components/activities/common/hints/authoring/hintActions';
import { getHints } from 'components/activities/common/hints/authoring/hintUtils';
import {
  createMatchRule,
  createRuleForIds,
  getResponses,
  invertRule,
  unionRules,
} from 'components/activities/common/responses/authoring/responseUtils';

const applyAction = (model: CheckAllThatApplyModelSchema, action: any) => {
  return produce(model, (state) => action(state, () => undefined));
};

const testDefaultModel = defaultCATAModel;

describe('check all that apply question functionality', () => {
  const model = testDefaultModel();

  it('can switch from simple to targeted feedback mode', () => {
    expect(model.type).toBe('SimpleCATA');
    const toggled: TargetedCATA = applyAction(model, CATAActions.toggleType()) as any;
    expect(toggled).toMatchObject({ type: 'TargetedCATA' });
    expect(toggled.authoring.targeted).toBeInstanceOf(Array);
    expect(toggled.authoring.targeted).toHaveLength(0);
  });

  it('can switch from targeted to simple feedback mode', () => {
    const toggled = applyAction(model, CATAActions.toggleType());
    const toggledBack = applyAction(toggled, CATAActions.toggleType());
    expect(toggledBack).toMatchObject({ type: 'SimpleCATA' });
    expect(toggledBack.authoring).not.toHaveProperty('targeted');
  });

  it('has a stem', () => {
    expect(model).toHaveProperty('stem');
  });

  it('can edit stem', () => {
    const newStemContent = makeStem('new content').content;
    expect(applyAction(model, StemActions.editStem(newStemContent)).stem).toMatchObject({
      content: newStemContent,
    });
  });

  it('has at least one choice', () => {
    expect(model).toHaveProperty('choices');
    expect(model.choices.length).toBeGreaterThan(0);
  });

  it('can add a choice', () => {
    const withChoiceAdded = applyAction(model, CATAActions.addChoice(makeChoice('')));
    expect(withChoiceAdded.choices.length).toBeGreaterThan(model.choices.length);
    expect(getChoiceIds(withChoiceAdded.authoring.incorrect)).toHaveLength(2);
    expect(getChoiceIds(withChoiceAdded.authoring.correct)).toHaveLength(1);
  });

  it('can toggle choice correctness', () => {
    // First choice is correct
    const firstChoice = model.choices[0];
    const modelWithFirstChoiceToggled = applyAction(
      model,
      CATAActions.toggleChoiceCorrectness(firstChoice.id),
    );
    expect(getChoiceIds(modelWithFirstChoiceToggled.authoring.correct)).not.toContain(
      firstChoice.id,
    );
    expect(getChoiceIds(modelWithFirstChoiceToggled.authoring.incorrect)).toContain(firstChoice.id);
  });

  it('can edit a choice', () => {
    const newChoiceContent = makeChoice('new content').content;
    const firstChoice = model.choices[0];
    expect(
      applyAction(model, ChoiceActions.editChoiceContent(firstChoice.id, newChoiceContent))
        .choices[0],
    ).toHaveProperty('content', newChoiceContent);
  });

  it('can remove a choice from simple CATA', () => {
    const firstChoice = model.choices[0];
    const newModel = applyAction(model, CATAActions.removeChoice(firstChoice.id));
    expect(newModel.choices).toHaveLength(1);
    expect(getChoiceIds(newModel.authoring.correct)).not.toContain(firstChoice);
    expect(getChoiceIds(newModel.authoring.incorrect)).not.toContain(firstChoice);
  });

  it('can remove a choice from targeted CATA responses', () => {
    const firstChoice = model.choices[0];
    const toggled = applyAction(model, CATAActions.toggleType());
    const newModel: TargetedCATA = applyAction(
      toggled,
      CATAActions.removeChoice(firstChoice.id),
    ) as any;
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
    const newFeedbackContent = makeFeedback('new content').content;
    const firstResponse = model.authoring.parts[0].responses[0];
    expect(
      applyAction(model, ResponseActions.editResponseFeedback(firstResponse.id, newFeedbackContent))
        .authoring.parts[0].responses[0].feedback,
    ).toHaveProperty('content', newFeedbackContent);
  });

  it('can add a targeted feedback in targeted mode', () => {
    expect(applyAction(model, CATAActions.addTargetedFeedback())).toEqual(model);
    const toggled = applyAction(model, CATAActions.toggleType());
    const withNewResponse: TargetedCATA = applyAction(
      toggled,
      CATAActions.addTargetedFeedback(),
    ) as any;
    expect(getResponses(withNewResponse).length).toBeGreaterThan(getResponses(model).length);
    expect(withNewResponse.authoring.targeted.length).toBe(1);
    expect(getChoiceIds(withNewResponse.authoring.targeted[0])).toHaveLength(0);
  });

  it('can remove a targeted feedback in targeted mode', () => {
    expect(applyAction(model, CATAActions.removeTargetedFeedback('id'))).toEqual(model);
    const toggled = applyAction(model, CATAActions.toggleType());
    const withNewResponse: TargetedCATA = applyAction(
      toggled,
      CATAActions.addTargetedFeedback(),
    ) as any;
    const removed: TargetedCATA = applyAction(
      withNewResponse,
      CATAActions.removeTargetedFeedback(getResponseId(withNewResponse.authoring.targeted[0])),
    ) as any;
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
    expect(unionRules([createMatchRule('id1'), invertRule(createMatchRule('id2'))])).toBe(
      '(!(input like {id2})) && (input like {id1})',
    );
  });

  it('can create rules to match certain ids and not match others', () => {
    const toMatch = ['id1', 'id2'];
    const notToMatch = ['id3'];
    expect(createRuleForIds(toMatch, notToMatch)).toEqual(
      '(!(input like {id3})) && (input like {id2} && (input like {id1}))',
    );
  });

  it('has at least 3 hints', () => {
    expect(getHints(model).length).toBeGreaterThanOrEqual(3);
  });

  it('can add a cognitive hint before the end of the array', () => {
    expect(getHints(applyAction(model, HintActions.addHint(makeHint('')))).length).toBeGreaterThan(
      getHints(model).length,
    );
  });

  it('can edit a hint', () => {
    const newHintContent = makeHint('new content').content;
    const firstHint = getHints(model)[0];
    expect(
      getHints(applyAction(model, HintActions.editHint(firstHint.id, newHintContent)))[0],
    ).toHaveProperty('content', newHintContent);
  });

  it('can remove a hint', () => {
    const firstHint = getHints(model)[0];
    expect(
      getHints(
        applyAction(model, HintActions.removeHint(firstHint.id, '$.authoring.parts[0].hints')),
      ),
    ).toHaveLength(2);
  });
});
