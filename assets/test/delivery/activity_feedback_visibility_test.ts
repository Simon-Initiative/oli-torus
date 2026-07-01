import { ActivityContext } from 'components/activities/DeliveryElement';
import {
  isOneAtATimeScoreAtTheEndDelivery,
  shouldShowActivityFeedback,
} from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { DeliveryMode } from 'components/activities/types';

const context = (overrides: Partial<ActivityContext> = {}): ActivityContext =>
  ({
    allowHints: false,
    batchScoring: true,
    bibParams: [],
    graded: true,
    groupId: null,
    isAnnotationLevel: false,
    learningLanguage: undefined,
    maxAttempts: 3,
    oneAtATime: false,
    ordinal: 1,
    pageAttemptGuid: 'page-attempt-guid',
    pageLinkParams: {},
    pageState: {},
    projectSlug: 'project',
    renderPointMarkers: false,
    resourceId: 1,
    scoringStrategyId: 1,
    sectionSlug: 'section',
    showFeedback: true,
    surveyId: null,
    userId: 1,
    variables: {},
    ...overrides,
  } as ActivityContext);

describe('activity feedback visibility', () => {
  const mode: DeliveryMode = 'delivery';

  it('suppresses activity-owned feedback for one-at-a-time score-at-the-end delivery', () => {
    const deliveryContext = context({ oneAtATime: true, batchScoring: true });

    expect(isOneAtATimeScoreAtTheEndDelivery(deliveryContext, mode)).toBe(true);
    expect(shouldShowActivityFeedback(deliveryContext, mode, true)).toBe(false);
  });

  it('allows activity-owned feedback for one-at-a-time score-as-you-go delivery', () => {
    expect(
      shouldShowActivityFeedback(context({ oneAtATime: true, batchScoring: false }), mode, true),
    ).toBe(true);
  });

  it('allows activity-owned feedback in review mode', () => {
    expect(
      shouldShowActivityFeedback(context({ oneAtATime: true, batchScoring: true }), 'review', true),
    ).toBe(true);
  });

  it('still requires evaluated state and feedback permission', () => {
    expect(shouldShowActivityFeedback(context(), mode, false)).toBe(false);
    expect(shouldShowActivityFeedback(context({ showFeedback: false }), mode, true)).toBe(false);
    expect(shouldShowActivityFeedback(context({ surveyId: 'survey' }), mode, true)).toBe(false);
  });
});
