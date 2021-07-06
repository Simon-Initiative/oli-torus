import { getResponses } from 'components/activities/common/responses/authoring/responseUtils';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { HasParts, makeFeedback, makeResponse, ScoringStrategy } from 'components/activities/types';
import { applyTestAction } from 'utils/test_utils';

describe('responses', () => {
  const model: HasParts = {
    authoring: {
      parts: [
        {
          id: '1',
          responses: [makeResponse('', 1, '')],
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
      applyTestAction(
        model,
        ResponseActions.editResponseFeedback(firstFeedback.id, newFeedbackContent),
      ).authoring.parts[0].responses[0].feedback,
    ).toHaveProperty('content', newFeedbackContent);
  });

  it('can edit rules', () => {
    const response = getResponses(model)[0];
    const newModel = applyTestAction(model, ResponseActions.editRule(response.id, 'rule'));
    expect(getResponses(newModel)[0].rule).toBe('rule');
  });

  it('can remove responses', () => {
    const response = getResponses(model)[0];
    const newModel = applyTestAction(model, ResponseActions.removeResponse(response.id));
    expect(getResponses(newModel)).toHaveLength(0);
  });
});
