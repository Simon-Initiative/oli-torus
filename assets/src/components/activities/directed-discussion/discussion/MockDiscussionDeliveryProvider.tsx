import React, { ReactNode } from 'react';
import { DeliveryElementProvider } from 'components/activities/DeliveryElementProvider';
import { ActivityState, PartState, Success } from 'components/activities/types';
import { DirectedDiscussionActivitySchema } from '../schema';

const nullHandler = () => Promise.resolve({ type: 'success' } as Success);

/**
 * A delivery provider that can be used on the instructor side of things to let the instructor
 * view the directed delivery.
 */
export const MockDiscussionDeliveryProvider: React.FC<{
  children: ReactNode;
  model: DirectedDiscussionActivitySchema;
  activityId: number;
  sectionSlug: string;
  projectSlug: string;
}> = ({ children, model, activityId, sectionSlug, projectSlug }) => {
  return (
    <DeliveryElementProvider
      model={model}
      state={{
        attemptGuid: '',
        attemptNumber: 1,
        dateEvaluated: null,
        dateSubmitted: null,
        score: null,
        outOf: null,
        parts: [],
        hasMoreAttempts: true,
        hasMoreHints: false,
        groupId: null,
      }}
      mode="preview"
      context={{
        graded: false,
        resourceId: activityId,
        bibParams: {},
        sectionSlug: sectionSlug,
        projectSlug: projectSlug,
        userId: 0,
        pageAttemptGuid: '',
        surveyId: '',
        groupId: '',
        showFeedback: false,
        renderPointMarkers: false,
        isAnnotationLevel: false,
        variables: {},
        pageLinkParams: {},
        allowHints: false,
      }}
      onSaveActivity={nullHandler}
      onSavePart={nullHandler}
      onRequestHint={() => Promise.resolve({ type: 'success', hasMoreHints: false })}
      onResetPart={() => Promise.resolve({ type: 'success', attemptState: {} as PartState })}
      onSubmitActivity={() => Promise.resolve({ type: 'success', actions: [] })}
      onResetActivity={() =>
        Promise.resolve({ type: 'success', attemptState: {} as ActivityState, model })
      }
      onSubmitPart={() => Promise.resolve({ type: 'success', actions: [] })}
      onSubmitEvaluations={() => Promise.resolve({ type: 'success', actions: [] })}
    >
      {children}
    </DeliveryElementProvider>
  );
};
