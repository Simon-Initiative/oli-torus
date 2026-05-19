import React from 'react';
import '@testing-library/jest-dom';
import { render, waitFor } from '@testing-library/react';
import { Environment } from 'janus-script';
import { Adaptive } from 'components/activities/adaptive/AdaptiveDelivery';

jest.mock('components/activities/adaptive/components/delivery/PartsLayoutRenderer', () => {
  return function MockPartsLayoutRenderer(props: any) {
    jest.requireActual('react').useEffect(() => {
      props.parts.forEach((part: any) => {
        props.onPartInit({ id: part.id, responses: [] });
      });
    }, []);

    return null;
  };
});

describe('AdaptiveDelivery', () => {
  it('uses the normal host onReady path in review mode', async () => {
    const onReady = jest.fn(() =>
      Promise.resolve({
        snapshot: { 'stage.part1.customCssClass': 'hidden' },
        context: { mode: 'REVIEW' },
        env: new Environment(),
        domain: 'stage',
      }),
    );

    render(
      <Adaptive
        mode="review"
        model={{
          id: 'adaptive_screen_1',
          resourceId: 1,
          content: {
            custom: {},
            partsLayout: [{ id: 'part1', type: 'janus-text-flow', custom: {} }],
          },
          authoring: { parts: [], transformations: [], previewText: '' },
        }}
        state={{
          attemptGuid: 'attempt-1',
          attemptNumber: 1,
          activityId: 1,
          dateEvaluated: null,
          dateSubmitted: null,
          score: null,
          outOf: null,
          parts: [],
          hasMoreAttempts: true,
          hasMoreHints: true,
          groupId: null,
        }}
        context={{
          graded: false,
          batchScoring: false,
          oneAtATime: false,
          maxAttempts: 0,
          scoringStrategyId: 0,
          ordinal: 1,
          sectionSlug: 'section-1',
          projectSlug: '',
          userId: 1,
          groupId: null,
          surveyId: null,
          bibParams: null,
          pageAttemptGuid: '',
          showFeedback: null,
          renderPointMarkers: false,
          isAnnotationLevel: false,
          variables: {},
          pageLinkParams: {},
          allowHints: false,
          responsiveLayout: false,
        }}
        onReady={onReady as any}
        onRequestHint={jest.fn() as any}
        onSavePart={jest.fn() as any}
        onSubmitPart={jest.fn() as any}
        onResetPart={jest.fn() as any}
        onSaveActivity={jest.fn() as any}
        onSubmitActivity={jest.fn() as any}
        onResetActivity={jest.fn() as any}
        onSubmitEvaluations={jest.fn() as any}
      />,
    );

    await waitFor(() => expect(onReady).toHaveBeenCalledWith('attempt-1', []));
  });
});
