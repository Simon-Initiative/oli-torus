import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDelivery';
import { ActivityModelSchema, HasChoices } from 'components/activities/types';
import {
  ActivityDeliveryState,
  activityDeliverySlice,
  initializeState,
  listenForParentSurveyReset,
  listenForParentSurveySubmit,
  listenForReviewAttemptChange,
} from 'data/activities/DeliveryState';
import { initialPartInputs } from 'data/activities/utils';
import { configureStore } from 'state/store';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { castPartId } from '../common/utils';
import * as ActivityTypes from '../types';
import { DiscussionParticipation } from './DiscussionParticipation';
import { DiscussionThread } from './DiscussionThread';
import { useDiscussion } from './discussion-hook';
import { DirectedDiscussionActivitySchema } from './schema';

// Used instead of the real 'onSaveActivity' to bypass saving state to the server when we are just
// about to submit that state with a submission. This saves a network call that isn't necessary and avoids
// perhaps a weird race condition (where the submit request could arrive before the save)
const noOpSave = (
  _guid: string,
  _partResponses: ActivityTypes.PartResponse[],
): Promise<ActivityTypes.Success> => Promise.resolve({ type: 'success' });

export const DirectedDiscussion: React.FC = () => {
  const {
    state: activityState,
    context,
    onSubmitActivity,
    onSaveActivity,
    onResetActivity,
    model,
  } = useDeliveryElementContext<DirectedDiscussionActivitySchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();
  const { surveyId } = context;
  const { writerContext } = useDeliveryElementContext<HasChoices & ActivityModelSchema>();

  const { loaded, posts, addPost } = useDiscussion(writerContext.sectionSlug, context.resourceId);

  const { activityId } = activityState;
  const hasActivityId = !!activityId;

  useEffect(() => {
    listenForParentSurveySubmit(surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(surveyId, dispatch, onResetActivity, {
      [activityState.parts[0].partId]: [],
    });

    listenForReviewAttemptChange(model, activityState.activityId as number, dispatch, context);
    dispatch(
      initializeState(activityState, initialPartInputs(model, activityState), model, context),
    );
  }, []);

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  return (
    <div className="activity mc-activity">
      <div className="activity-content">
        <StemDeliveryConnected />
        <DiscussionParticipation requirements={model.participation} />
        <DiscussionThread posts={posts} onPost={addPost} />
        <HintsDeliveryConnected
          partId={castPartId(activityState.parts[0].partId)}
          resetPartInputs={{ [activityState.parts[0].partId]: [] }}
          shouldShow
        />
        {/* <EvaluationConnected /> */}
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class DirectedDiscussionDelivery extends DeliveryElement<DirectedDiscussionActivitySchema> {
  render(
    mountPoint: HTMLDivElement,
    props: DeliveryElementProps<DirectedDiscussionActivitySchema>,
  ) {
    const store = configureStore({}, activityDeliverySlice.reducer, {
      name: 'DirectedDiscussionDelivery',
    });

    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <DirectedDiscussion />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, DirectedDiscussionDelivery);
