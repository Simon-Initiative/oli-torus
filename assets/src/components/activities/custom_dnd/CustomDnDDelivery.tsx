import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDelivery';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/reset_button/ResetButtonConnected';
import { Provider, useDispatch, useSelector } from 'react-redux';
import {
  ActivityDeliveryState,
  activityDeliverySlice,
  initializeState,
  resetAction,
  listenForParentSurveyReset,
  listenForParentSurveySubmit,
  submitPart,
  resetAndSubmitPart,
} from 'data/activities/DeliveryState';

import { safelySelectFiles } from 'data/activities/utils';

import { configureStore } from 'state/store';
import { DeliveryElement, DeliveryElementProps } from 'components/activities/DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { Manifest, PartState } from 'components/activities/types';
import { CustomDnDSchema } from 'components/activities/custom_dnd/schema';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { DragCanvas, ResetListener } from './DragCanvas';
import { FocusedFeedback } from './FocusedFeedback';
import { FocusedHints } from './FocusedHints';

export const CustomDnDComponent: React.FC = () => {
  const {
    model,
    state,
    mode,
    context,
    onResetActivity,
    onSubmitActivity,
    onResetPart,
    onSubmitPart,
  } = useDeliveryElementContext<CustomDnDSchema>();
  const { surveyId, sectionSlug } = context;
  const initialState = state.parts.reduce((m: any, p) => {
    if (p.response !== null) {
      m[p.partId] = p.response.input;
    }
    return m;
  }, {});

  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const [focusedPart, setFocusedPart] = useState<string | null>(null);
  const [resetListener, setResetListener] = useState<ResetListener | null>(null);
  const dispatch = useDispatch();

  useEffect(() => {
    listenForParentSurveySubmit(surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(surveyId, dispatch, onResetActivity, { [DEFAULT_PART_ID]: [] });

    dispatch(
      initializeState(
        state,
        safelySelectFiles(state).caseOf({
          just: (input) => input,
          nothing: () => ({
            [DEFAULT_PART_ID]: [],
          }),
        }),
        model,
        sectionSlug,
      ),
    );
  }, []);

  const findPart = (partId: string) => {
    return uiState.attemptState.parts.find((p) => p.partId === partId) as any;
  };
  const toStudentResponse = (input: string) => ({ input });

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  const onSubmit = (partId: string, value: string) => {
    const partState: PartState = findPart(partId);

    if (partState.dateEvaluated !== null) {
      dispatch(
        resetAndSubmitPart(
          uiState.attemptState.attemptGuid,
          findPart(partId).attemptGuid,
          toStudentResponse(value),
          onResetPart,
          onSubmitPart,
        ),
      );
    } else {
      dispatch(
        submitPart(
          uiState.attemptState.attemptGuid,
          findPart(partId).attemptGuid,
          toStudentResponse(value),
          onSubmitPart,
        ),
      );
    }
  };

  const editMode = mode !== 'review' && uiState.attemptState.dateEvaluated === null;

  return (
    <div className="activity cata-activity">
      <div className="activity-content">
        <StemDeliveryConnected />
        <DragCanvas
          model={model}
          initialState={initialState}
          editMode={editMode}
          activityAttemptGuid={uiState.attemptState.attemptGuid}
          onRegisterResetCallback={(listener) => {
            setResetListener(() => listener);
          }}
          onSubmitPart={onSubmit}
          onFocusChange={(partId) => setFocusedPart(partId)}
        />
        <GradedPointsConnected />

        <ResetButtonConnected
          onReset={() => {
            if (resetListener !== null) {
              // This informs the non-React DragCanvas impl to move all draggables
              // back to their original location
              resetListener();
            }

            const partInputs = uiState.attemptState.parts.reduce((m: any, p) => {
              m[p.partId] = '';
              return m;
            }, {});
            dispatch(resetAction(onResetActivity, partInputs));
          }}
        />

        <FocusedFeedback focusedPart={focusedPart} />
        <FocusedHints focusedPart={focusedPart} />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class CustomDnDDelivery extends DeliveryElement<CustomDnDSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<CustomDnDSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer);
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <CustomDnDComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.delivery.element, CustomDnDDelivery);
