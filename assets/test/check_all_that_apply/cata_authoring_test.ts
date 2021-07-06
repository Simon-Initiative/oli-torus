import { CATAActions } from 'components/activities/check_all_that_apply/actions';
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
import { makeChoice } from 'components/activities/types';
import { getHints } from 'components/activities/common/hints/authoring/hintUtils';
import { getResponses } from 'components/activities/common/responses/authoring/responseUtils';

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
    const newModel: TargetedCATA = applyAction(toggled, CATAActions.removeChoice(firstChoice.id));
    newModel.authoring.targeted.forEach((assoc) =>
      expect(getChoiceIds(assoc)).not.toContain(firstChoice.id),
    );
  });

  it('has one correct response', () => {
    expect(getCorrectResponse(model)).toBeTruthy();
  });

  it('has one incorrect response', () => {
    expect(getIncorrectResponse(model)).toBeTruthy();
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

  it('has at least 3 hints', () => {
    expect(getHints(model).length).toBeGreaterThanOrEqual(3);
  });
});
