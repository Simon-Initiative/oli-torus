import { getHints } from 'components/activities/common/hints/authoring/hintUtils';
import {
  getChoiceIds,
  getCorrectChoiceIds,
  getCorrectResponse,
  getIncorrectResponse,
  getResponseId,
  getResponses,
  getTargetedChoiceIds,
  getTargetedResponses,
} from 'components/activities/common/responses/authoring/responseUtils';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { Actions } from 'components/activities/ordering/actions';
import { defaultOrderingModel } from 'components/activities/ordering/utils';
import { dispatch } from 'utils/test_utils';

const testDefaultModel = defaultOrderingModel;

describe('ordering question', () => {
  const model = testDefaultModel();

  it('has correct feedback that correspond to all choices', () => {
    expect(getCorrectChoiceIds(model)).toHaveLength(model.choices.length);
    expect(getTargetedChoiceIds(model)).toHaveLength(0);
  });

  it('has a stem', () => {
    expect(model).toHaveProperty('stem');
  });

  it('has at least one choice', () => {
    expect(model).toHaveProperty('choices');
    expect(model.choices.length).toBeGreaterThan(0);
  });

  it('can remove a choice', () => {
    const firstChoice = model.choices[0];
    const newModel = dispatch(model, Actions.removeChoiceAndUpdateRules(firstChoice.id));
    expect(newModel.choices).toHaveLength(1);
    expect(getChoiceIds(newModel.authoring.correct)).not.toContain(firstChoice);
  });

  it('can remove a choice', () => {
    const firstChoice = model.choices[0];
    const newModel = dispatch(model, Actions.removeChoiceAndUpdateRules(firstChoice.id));
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

  it('can add a targeted feedback', () => {
    const withNewResponse = dispatch(model, Actions.addTargetedFeedback());
    expect(getResponses(withNewResponse).length).toBeGreaterThan(getResponses(model).length);
    expect(withNewResponse.authoring.targeted.length).toBe(1);
    expect(getChoiceIds(withNewResponse.authoring.targeted[0])).toHaveLength(2);
  });

  it('can remove a targeted feedback', () => {
    const withNewResponse = dispatch(model, Actions.addTargetedFeedback());
    const removed = dispatch(
      withNewResponse,
      ResponseActions.removeTargetedFeedback(getResponseId(withNewResponse.authoring.targeted[0])),
    );
    expect(getResponses(removed)).toHaveLength(2);
    expect(getTargetedResponses(removed)).toHaveLength(0);
  });

  it('has at least 3 hints', () => {
    expect(getHints(model).length).toBeGreaterThanOrEqual(3);
  });
});
