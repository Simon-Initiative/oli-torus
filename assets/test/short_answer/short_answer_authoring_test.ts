import { ShortAnswerActions } from 'components/activities/short_answer/actions';
import { defaultModel } from 'components/activities/short_answer/utils';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { dispatch } from 'utils/test_utils';

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
    const updated = dispatch(model, ShortAnswerActions.addResponse());
    expect(updated.authoring.parts[0].responses[0].score).toBe(1);
    expect(updated.authoring.parts[0].responses[1].score).toBe(0);
    expect(updated.authoring.parts[0].responses[2].score).toBe(0);
    expect(updated.authoring.parts[0].responses[0].rule).toBe('input contains {answer}');
    expect(updated.authoring.parts[0].responses[1].rule).toBe('input contains {another answer}');
    expect(updated.authoring.parts[0].responses[2].rule).toBe('input like {.*}');

    expect(
      dispatch(
        updated,
        ResponseActions.removeResponse(updated.authoring.parts[0].responses[1].id),
      ).authoring.parts[0].responses,
    ).toHaveLength(2);
  });

  it('can add and remove a response in numeric mode', () => {
    let updated = dispatch(model, ShortAnswerActions.setInputType('numeric'));

    updated = dispatch(updated, ShortAnswerActions.addResponse());
    expect(updated.authoring.parts[0].responses[0].score).toBe(1);
    expect(updated.authoring.parts[0].responses[1].score).toBe(0);
    expect(updated.authoring.parts[0].responses[2].score).toBe(0);
    expect(updated.authoring.parts[0].responses[0].rule).toBe('input = {1}');
    expect(updated.authoring.parts[0].responses[1].rule).toBe('input = {1}');
    expect(updated.authoring.parts[0].responses[2].rule).toBe('input like {.*}');

    expect(
      dispatch(
        updated,
        ResponseActions.removeResponse(updated.authoring.parts[0].responses[1].id),
      ).authoring.parts[0].responses,
    ).toHaveLength(2);
  });
});
