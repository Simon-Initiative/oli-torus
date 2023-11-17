import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { ActivityModelSchema } from 'components/activities/types';
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
import * as ActivityTypes from '../types';
import { DirectedDiscussion } from './discussion/DirectedDiscussion';
import { DirectedDiscussionActivitySchema } from './schema';

export const InternalDirectedDiscussion: React.FC = () => {
  const {
    state: activityState,
    context,
    onSubmitActivity,
    onResetActivity,
    model,
  } = useDeliveryElementContext<DirectedDiscussionActivitySchema>();

  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();
  const { surveyId } = context;
  const { writerContext } = useDeliveryElementContext<ActivityModelSchema>();

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
  if (!uiState.partState || !activityState.activityId || !writerContext.sectionSlug) {
    console.warn('Discussion activity not initialized yet', {
      partState: uiState.partState,
      activityState: activityState,
      writerContext: writerContext,
    });
    return <div>Discussion Activity Loading</div>;
  }

  return (
    <DirectedDiscussion
      model={model}
      resourceId={activityState.activityId}
      sectionSlug={writerContext.sectionSlug}
    />
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
          <InternalDirectedDiscussion />
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
