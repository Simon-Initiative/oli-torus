import { CATAActions } from 'components/activities/check_all_that_apply/actions';
import { defaultCATAModel } from 'components/activities/check_all_that_apply/utils';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { makeChoice } from 'components/activities/types';
import { Hints } from 'data/activities/model/hints';
import {
  getChoiceIds,
  getCorrectResponse,
  getIncorrectResponse,
  getResponseId,
  getResponses,
  getTargetedResponses,
} from 'data/activities/model/responses';
import { dispatch } from 'utils/test_utils';

const DEFAULT_PART_ID = '1';
const testDefaultModel = defaultCATAModel;

describe('check all that apply question functionality', () => {
  const model = testDefaultModel();

  it('has a stem', () => {
    expect(model).toHaveProperty('stem');
  });

  it('has at least one choice', () => {
    expect(model).toHaveProperty('choices');
    expect(model.choices.length).toBeGreaterThan(0);
  });

  it('can add a choice', () => {
    const withChoiceAdded = dispatch(model, CATAActions.addChoice(makeChoice('')));
    expect(withChoiceAdded.choices.length).toBeGreaterThan(model.choices.length);
    expect(getChoiceIds(withChoiceAdded.authoring.correct)).toHaveLength(1);
  });

  it('can toggle choice correctness', () => {
    // First choice is correct
    const firstChoice = model.choices[0];
    const modelWithFirstChoiceToggled = dispatch(
      model,
      CATAActions.toggleChoiceCorrectness(firstChoice.id),
    );
    expect(getChoiceIds(modelWithFirstChoiceToggled.authoring.correct)).not.toContain(
      firstChoice.id,
    );
  });

  it('can remove a choice', () => {
    const firstChoice = model.choices[0];
    const newModel = dispatch(model, CATAActions.removeChoiceAndUpdateRules(firstChoice.id));
    expect(newModel.choices).toHaveLength(1);
    expect(getChoiceIds(newModel.authoring.correct)).not.toContain(firstChoice);
  });

  it('can remove a choice from targeted catas', () => {
    const firstChoice = model.choices[0];
    const newModel = dispatch(model, CATAActions.removeChoiceAndUpdateRules(firstChoice.id));
    newModel.authoring.targeted.forEach((assoc) =>
      expect(getChoiceIds(assoc)).not.toContain(firstChoice.id),
    );
  });

  it('has one correct response', () => {
    expect(getCorrectResponse(model, DEFAULT_PART_ID)).toBeTruthy();
  });

  it('has one incorrect response', () => {
    expect(getIncorrectResponse(model, DEFAULT_PART_ID)).toBeTruthy();
  });

  it('can add a targeted feedback', () => {
    const withNewResponse = dispatch(model, CATAActions.addTargetedFeedback());
    expect(getResponses(withNewResponse).length).toBeGreaterThan(getResponses(model).length);
    expect(withNewResponse.authoring.targeted.length).toBe(1);
    expect(getChoiceIds(withNewResponse.authoring.targeted[0])).toHaveLength(0);
  });

  it('can remove a targeted feedback', () => {
    const withNewResponse = dispatch(model, CATAActions.addTargetedFeedback());
    const removed = dispatch(
      withNewResponse,
      ResponseActions.removeTargetedFeedback(getResponseId(withNewResponse.authoring.targeted[0])),
    );
    expect(getResponses(removed)).toHaveLength(2);
    expect(getTargetedResponses(removed)).toHaveLength(0);
  });

  it('has at least 3 hints', () => {
    expect(Hints.byPart(model, DEFAULT_PART_ID).length).toBeGreaterThanOrEqual(3);
  });
});
