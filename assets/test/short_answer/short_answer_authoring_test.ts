import { ShortAnswerActions } from 'components/activities/short_answer/actions';
import * as ContentModel from 'data/content/model';
import { ShortAnswerModelSchema } from 'components/activities/short_answer/schema';
import { makeFeedback, makeResponse, makeStem, ScoringStrategy } from 'components/activities/types';
import produce from 'immer';
import { containsRule, matchRule } from 'components/activities/common/responses/authoring/rules';
import { defaultModel } from 'components/activities/short_answer/utils';
import { applyTestAction } from 'test/utils/misc_utils';

describe('short answer question', () => {
  const model = defaultModel();

  it('has a stem', () => {
    expect(model).toHaveProperty('stem');
  });

  it('has input type', () => {
    expect(model).toHaveProperty('inputType');
  });

  it('has at least 3 hints', () => {
    expect(model.authoring.parts[0].hints.length).toBeGreaterThanOrEqual(3);
  });

  it('can add and remove a response in text mode', () => {
    const updated = applyTestAction(model, ShortAnswerActions.addResponse());
    expect(updated.authoring.parts[0].responses[0].score).toBe(1);
    expect(updated.authoring.parts[0].responses[1].score).toBe(0);
    expect(updated.authoring.parts[0].responses[2].score).toBe(0);
    expect(updated.authoring.parts[0].responses[0].rule).toBe('input like {answer}');
    expect(updated.authoring.parts[0].responses[1].rule).toBe('input like {another answer}');
    expect(updated.authoring.parts[0].responses[2].rule).toBe('input like {.*}');

    expect(
      applyTestAction(
        updated,
        ShortAnswerActions.removeReponse(updated.authoring.parts[0].responses[1].id),
      ).authoring.parts[0].responses,
    ).toHaveLength(2);
  });

  it('can add and remove a response in numeric mode', () => {
    let updated = applyTestAction(model, ShortAnswerActions.setInputType('numeric'));

    updated = applyTestAction(updated, ShortAnswerActions.addResponse());
    expect(updated.authoring.parts[0].responses[0].score).toBe(1);
    expect(updated.authoring.parts[0].responses[1].score).toBe(0);
    expect(updated.authoring.parts[0].responses[2].score).toBe(0);
    expect(updated.authoring.parts[0].responses[0].rule).toBe('input = {1}');
    expect(updated.authoring.parts[0].responses[1].rule).toBe('input = {1}');
    expect(updated.authoring.parts[0].responses[2].rule).toBe('input like {.*}');

    expect(
      applyTestAction(
        updated,
        ShortAnswerActions.removeReponse(updated.authoring.parts[0].responses[1].id),
      ).authoring.parts[0].responses,
    ).toHaveLength(2);
  });
});
