import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDelivery';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/reset_button/ResetButtonConnected';
import { Provider, useDispatch, useSelector, useStore } from 'react-redux';
import {
  ActivityDeliveryState,
  activityDeliverySlice,
  initializeState,
  resetAction,
  listenForParentSurveyReset,
  listenForParentSurveySubmit,
  listenForReviewAttemptChange,
  submitPart,
  resetAndSubmitPart,
  resetAndSavePart,
  resetPart,
} from 'data/activities/DeliveryState';

import { safelySelectFiles } from 'data/activities/utils';

import { configureStore } from 'state/store';
import { DeliveryElement, DeliveryElementProps } from 'components/activities/DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { Manifest, PartState } from 'components/activities/types';
import { CustomDnDSchema } from 'components/activities/custom_dnd/schema';
import { DragCanvas, ResetListener } from './DragCanvas';
import { FocusedFeedback } from './FocusedFeedback';
import { FocusedHints } from './FocusedHints';
import { castPartId } from '../common/utils';

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
  const { surveyId } = context;

  // Question model contains partIds w/choice values of form partId_choiceId.
  // Initial Torus implementation attached partIds to targets and choiceIds
  // to draggables ("initiators"). But for some legacy questions it is
  // necessary to do the other way round because fewer draggables than targets.
  // partIdBearers will indicate which DND elements carry the partIds to enable
  // code to handle either form. Note model is the same in either case.
  type DndElementType = 'draggables' | 'targets';
  const firstPartId = state.parts[0].partId;
  const partIdBearers: DndElementType = model.initiators.includes(`input_val="${firstPartId}"`)
    ? 'draggables'
    : 'targets';

  // state we pass is always a mapping from targetId to draggableId
  const initialState = state.parts.reduce((m: any, p) => {
    if (p.response !== null) {
      const choiceId = p.response.input.substr((p.partId as string).length + 1);
      if (partIdBearers === 'targets') {
        m[p.partId] = choiceId;
      } else {
        m[choiceId] = p.partId;
      }
    }
    return m;
  }, {});

  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const [focusedPart, setFocusedPart] = useState<string | null>(null);
  const [resetListener, setResetListener] = useState<ResetListener | null>(null);
  const dispatch = useDispatch();
  const { getState } = useStore();

  useEffect(() => {
    listenForParentSurveySubmit(surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(surveyId, dispatch, onResetActivity, {
      [castPartId(state.parts[0].partId)]: [],
    });
    listenForReviewAttemptChange(model, state.activityId as number, dispatch, context);

    dispatch(
      initializeState(
        state,
        safelySelectFiles(state).caseOf({
          just: (input) => input,
          nothing: () => ({
            [castPartId(state.parts[0].partId)]: [],
          }),
        }),
        model,
        context,
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

  const onFocusChange = (targetId: string, draggableId: string | null) => {
    setFocusedPart(partIdBearers === 'targets' ? targetId : draggableId);
  };

  const onDetach = (targetId: string, draggableId: string) => {
    // update on detaching draggable from target
    const partId = partIdBearers === 'targets' ? targetId : draggableId;

    const part = findPart(partId);
    if (part === null) console.log('part not found! id=' + partId);
    else {
      dispatch(resetPart(uiState.attemptState.attemptGuid, part.attemptGuid, onResetPart));
    }
  };

  const onSubmit = (targetId: string, draggableId: string) => {
    const [partId, choiceId] =
      partIdBearers === 'targets' ? [targetId, draggableId] : [draggableId, targetId];
    const response = partId + '_' + choiceId;
    // console.log('DND onSubmit: partId=' + partId + ' response= ' + response);

    const state = getState();
    const part = state.attemptState.parts.find((p: any) => p.partId === partId);
    if (part !== undefined) {
      if (part.dateEvaluated !== null) {
        dispatch(
          resetAndSubmitPart(
            uiState.attemptState.attemptGuid,
            part.attemptGuid,
            toStudentResponse(response),
            onResetPart,
            onSubmitPart,
          ),
        );
      } else {
        dispatch(
          submitPart(
            uiState.attemptState.attemptGuid,
            part.attemptGuid,
            toStudentResponse(response),
            onSubmitPart,
          ),
        );
      }
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
          onFocusChange={onFocusChange}
          onDetach={onDetach}
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
