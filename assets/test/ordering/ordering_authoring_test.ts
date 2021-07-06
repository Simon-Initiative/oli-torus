import { Actions } from 'components/activities/ordering/actions';
import { TargetedOrdering } from 'components/activities/ordering/schema';
import {
  defaultOrderingModel,
  getChoiceIds,
  getCorrectResponse,
  getHints,
  getTargetedChoiceIds,
  getIncorrectResponse,
  getResponseId,
  getResponses,
  getTargetedResponses,
  getCorrectOrdering,
} from 'components/activities/ordering/utils';
import { applyTestAction } from 'utils/test_utils';

const testDefaultModel = defaultOrderingModel;

describe('ordering question', () => {
  const model = testDefaultModel();

  it('has correct feedback that correspond to all choices', () => {
    expect(getCorrectOrdering(model)).toHaveLength(model.choices.length);
    const toggled: TargetedOrdering = applyTestAction(model as any, Actions.toggleType());
    expect(getTargetedChoiceIds(toggled)).toHaveLength(0);
  });

  it('can switch from simple to targeted feedback mode', () => {
    expect(model.type).toBe('SimpleOrdering');
    const toggled: TargetedOrdering = applyTestAction(model as any, Actions.toggleType());
    expect(toggled.type).toBe('TargetedOrdering');
    expect(toggled.authoring.targeted).toBeInstanceOf(Array);
    expect(toggled.authoring.targeted).toHaveLength(0);
  });

  it('can switch from targeted to simple feedback mode', () => {
    const toggled = applyTestAction(model, Actions.toggleType());
    const toggledBack = applyTestAction(toggled, Actions.toggleType());
    expect(toggledBack).toMatchObject({ type: 'SimpleOrdering' });
    expect(toggledBack.authoring).not.toHaveProperty('targeted');
  });

  it('has a stem', () => {
    expect(model).toHaveProperty('stem');
  });

  it('has at least one choice', () => {
    expect(model).toHaveProperty('choices');
    expect(model.choices.length).toBeGreaterThan(0);
  });

  it('can remove a choice from simple Ordering', () => {
    const firstChoice = model.choices[0];
    const newModel = applyTestAction(model, Actions.removeChoice(firstChoice.id));
    expect(newModel.choices).toHaveLength(1);
    expect(getChoiceIds(newModel.authoring.correct)).not.toContain(firstChoice);
  });

  it('can remove a choice from targeted Ordering responses', () => {
    const firstChoice = model.choices[0];
    const toggled = applyTestAction(model, Actions.toggleType());
    const newModel: TargetedOrdering = applyTestAction(
      toggled as any,
      Actions.removeChoice(firstChoice.id),
    );
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
    expect(applyTestAction(model, Actions.addTargetedFeedback())).toEqual(model);
    const toggled: TargetedOrdering = applyTestAction(model as any, Actions.toggleType());
    const withNewResponse = applyTestAction(toggled, Actions.addTargetedFeedback());
    expect(getResponses(withNewResponse).length).toBeGreaterThan(getResponses(model).length);
    expect(withNewResponse.authoring.targeted.length).toBe(1);
    expect(getChoiceIds(withNewResponse.authoring.targeted[0])).toHaveLength(0);
  });

  it('can remove a targeted feedback in targeted mode', () => {
    expect(applyTestAction(model, Actions.removeTargetedFeedback('id'))).toEqual(model);
    const toggled: TargetedOrdering = applyTestAction(model as any, Actions.toggleType());
    const withNewResponse = applyTestAction(toggled, Actions.addTargetedFeedback());
    const removed = applyTestAction(
      withNewResponse,
      Actions.removeTargetedFeedback(getResponseId(withNewResponse.authoring.targeted[0])),
    );
    expect(getResponses(removed)).toHaveLength(2);
    expect(getTargetedResponses(removed)).toHaveLength(0);
  });

  it('has at least 3 hints', () => {
    expect(getHints(model).length).toBeGreaterThanOrEqual(3);
  });
});
