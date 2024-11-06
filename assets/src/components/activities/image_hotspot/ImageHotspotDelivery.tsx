import React, { useEffect, useRef } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import {
  ActivityDeliveryState,
  activityDeliverySlice,
  initializeState,
  isEvaluated,
  listenForParentSurveyReset,
  listenForParentSurveySubmit,
  listenForReviewAttemptChange,
  resetAction,
  resetAndSubmitActivity,
  setSelection,
  submit,
} from 'data/activities/DeliveryState';
import { initialPartInputs, isCorrect } from 'data/activities/utils';
import { configureStore } from 'state/store';
import guid from 'utils/guid';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { SubmitResetConnected } from '../common/delivery/SubmitReset';
import { EvaluationConnected } from '../common/delivery/evaluation/EvaluationConnected';
import { GradedPointsConnected } from '../common/delivery/graded_points/GradedPointsConnected';
import { HintsDeliveryConnected } from '../common/hints/delivery/HintsDeliveryConnected';
import { StemDelivery } from '../common/stem/delivery/StemDelivery';
import { castPartId } from '../common/utils';
import * as ActivityTypes from '../types';
import { Hotspot, ImageHotspotModelSchema, getShape } from './schema';
import { HS_COLOR, drawHotspotShape } from './utils';

// Used instead of the real 'onSaveActivity' to bypass saving state to the server when we are just
// about to submit that state with a submission. This saves a network call that isn't necessary and avoids
// perhaps a weird race condition (where the submit request could arrive before the save)
const noOpSave = (
  _guid: string,
  _partResponses: ActivityTypes.PartResponse[],
): Promise<ActivityTypes.Success> => Promise.resolve({ type: 'success' });

const ImageHotspotComponent: React.FC = () => {
  const {
    state: activityState,
    context,
    model,
    writerContext,
    onSubmitActivity,
    onSaveActivity,
    onResetActivity,
  } = useDeliveryElementContext<ImageHotspotModelSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  const emptySelectionMap = {};

  useEffect(() => {
    listenForParentSurveySubmit(context.surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(context.surveyId, dispatch, onResetActivity, emptySelectionMap);
    listenForReviewAttemptChange(model, activityState.activityId as number, dispatch, context);

    dispatch(
      initializeState(activityState, initialPartInputs(model, activityState), model, context),
    );
  }, []);

  const partId = castPartId(activityState.parts[0].partId);
  const partState = uiState.partState?.[partId];
  const selected = partState?.studentInput;

  const [hovered, setHovered] = React.useState<Hotspot | null>(null);
  // for one-time ID generation:
  const [mapName] = React.useState<string>(guid());

  const canvasRef = useRef<HTMLCanvasElement>(null);
  const canvasRef2 = useRef<HTMLCanvasElement>(null);
  const canvas = canvasRef.current;
  const ctx = canvas?.getContext('2d');

  const showSelected = () => {
    if (canvas && ctx) {
      ctx?.clearRect(0, 0, canvas?.width, canvas.height);
    }
    if (selected) {
      selected.map((id) => {
        const hotspot = model.choices.find((hs) => hs.id === id);
        if (ctx && hotspot) {
          drawHotspotShape(
            ctx,
            hotspot,
            isEvaluated(uiState) && isCorrect(uiState.attemptState) ? '#00FF00' : HS_COLOR,
          );
        }
      });
    }
  };

  const showHovered = () => {
    const canvas2 = canvasRef2.current;
    const ctx2 = canvas2?.getContext('2d');
    if (canvas2) ctx2?.clearRect(0, 0, canvas2.width, canvas2.height);
    if (ctx2 && hovered) {
      drawHotspotShape(ctx2, hovered, HS_COLOR, false);
    }
  };

  useEffect(showSelected);
  useEffect(showHovered, [hovered]);

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  const onSelect = (partId: string, choiceId: string) => {
    // CATA type or non-submit context: just save selection
    if (model.multiple || context.graded || context.surveyId !== null) {
      dispatch(
        setSelection(partId, choiceId, onSaveActivity, model.multiple ? 'multiple' : 'single'),
      );
    } else {
      // single select: update selection locally and autosubmit as for MCQ
      dispatch(setSelection(partId, choiceId, noOpSave, 'single'));

      if (isEvaluated(uiState)) {
        dispatch(
          resetAndSubmitActivity(
            uiState.attemptState.attemptGuid,
            [{ input: choiceId }],
            onResetActivity,
            onSubmitActivity,
          ),
        );
      } else {
        dispatch(submit(onSubmitActivity));
      }
    }
  };

  const onClickHotspot = (hs: Hotspot) => {
    const disabled = context.graded && isEvaluated(uiState);
    if (!disabled) onSelect(partId, hs.id);
  };

  return (
    <div className="activity multiple-choice-activity">
      <div className="activity-content">
        <StemDelivery
          stem={(uiState.model as ImageHotspotModelSchema).stem}
          context={writerContext}
        />
        <div
          style={{ position: 'relative', width: model.width, height: model.height }}
          tabIndex={0}
        >
          {/* bottom layer: image with associated map */}
          <img src={model.imageURL} style={{ position: 'absolute' }} useMap={'#' + mapName} />
          {/* overlay 1: semi-transparent canvas for drawing selected area shapes */}
          <canvas
            ref={canvasRef}
            height={model.height}
            width={model.width}
            style={{ position: 'absolute', opacity: 0.5, pointerEvents: 'none' }}
          />
          {/* overlay 2: semi-transparent canvas for drawing hovered area shapes */}
          <canvas
            ref={canvasRef2}
            height={model.height}
            width={model.width}
            style={{ position: 'absolute', opacity: 0.5, pointerEvents: 'none' }}
          />
          <map name={mapName}>
            {model.choices.filter(getShape).map((hs) => (
              <area
                id={hs.id}
                key={hs.id}
                shape={getShape(hs)}
                coords={hs.coords.join(',')}
                onClick={() => onClickHotspot(hs)}
                onMouseEnter={() => setHovered(hs)}
                onMouseLeave={() => setHovered(null)}
                title={hs.title}
                tabIndex={0}
              />
            ))}
          </map>
        </div>

        <GradedPointsConnected />

        {/* single selection like MCQ: no submit button. multiple like CATA */}
        {model.multiple && (
          <SubmitResetConnected
            onReset={() => dispatch(resetAction(onResetActivity, { [partId]: [] }))}
          />
        )}

        <HintsDeliveryConnected partId={castPartId(activityState.parts[0].partId)} />
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class ImageHotspotDelivery extends DeliveryElement<ImageHotspotModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<ImageHotspotModelSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer, {
      name: 'ImageHotspotDelivery',
    });
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <ImageHotspotComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, ImageHotspotDelivery);
