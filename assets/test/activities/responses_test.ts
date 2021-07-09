import { getResponses } from 'components/activities/common/responses/authoring/responseUtils';
import { matchRule } from 'components/activities/common/responses/authoring/rules';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import {
  ChoiceIdsToResponseId,
  HasChoices,
  HasParts,
  makeChoice,
  makeFeedback,
  makeResponse,
  ScoringStrategy,
} from 'components/activities/types';
import { dispatch } from 'utils/test_utils';

describe('responses', () => {
  const choice = makeChoice('a');
  const response = makeResponse(matchRule(choice.id), 1, '');
  const model: HasParts & HasChoices & { authoring: { targeted: ChoiceIdsToResponseId[] } } = {
    choices: [choice],
    authoring: {
      targeted: [[[choice.id], response.id]],
      parts: [
        {
          id: '1',
          responses: [response, makeResponse(matchRule('.*'), 0, '')],
          hints: [],
          scoringStrategy: {} as ScoringStrategy,
        },
      ],
    },
  };
  it('can edit feedback', () => {
    const newFeedbackContent = makeFeedback('new content').content;
    const firstFeedback = model.authoring.parts[0].responses[0];
    expect(
      dispatch(model, ResponseActions.editResponseFeedback(firstFeedback.id, newFeedbackContent))
        .authoring.parts[0].responses[0].feedback,
    ).toHaveProperty('content', newFeedbackContent);
  });

  it('can edit rules', () => {
    const response = getResponses(model)[0];
    const newModel = dispatch(model, ResponseActions.editRule(response.id, 'rule'));
    expect(getResponses(newModel)[0].rule).toBe('rule');
  });

  it('can remove responses', () => {
    const response = getResponses(model)[0];
    const newModel = dispatch(model, ResponseActions.removeResponse(response.id));
    expect(getResponses(newModel)).toHaveLength(1);
  });

  it('can remove targeted feedback (responses)', () => {
    const response = getResponses(model)[0];
    const newModel = dispatch(model, ResponseActions.removeTargetedFeedback(response.id));
    expect(newModel.authoring.parts[0].responses).toHaveLength(1);
    expect(newModel.authoring.targeted).toHaveLength(0);
  });
});
