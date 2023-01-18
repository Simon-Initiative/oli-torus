import React, { useEffect, useRef } from 'react';
import ReactDOM from 'react-dom';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { getShape, Hotspot, ImageHotspotModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { StemDelivery } from '../common/stem/delivery/StemDelivery';
import { configureStore } from 'state/store';
import {
  activityDeliverySlice,
  ActivityDeliveryState,
  initializeState,
  setSelection,
  resetAction,
  isEvaluated,
  listenForParentSurveySubmit,
  listenForParentSurveyReset,
  listenForReviewAttemptChange,
} from 'data/activities/DeliveryState';
import { Provider, useSelector, useDispatch } from 'react-redux';
import { initialPartInputs, isCorrect } from 'data/activities/utils';
import { SubmitButtonConnected } from '../common/delivery/submit_button/SubmitButtonConnected';
import { HintsDeliveryConnected } from '../common/hints/delivery/HintsDeliveryConnected';
import { EvaluationConnected } from '../common/delivery/evaluation/EvaluationConnected';
import { GradedPointsConnected } from '../common/delivery/graded_points/GradedPointsConnected';
import { ResetButtonConnected } from '../common/delivery/reset_button/ResetButtonConnected';
import { useDeliveryElementContext, DeliveryElementProvider } from '../DeliveryElementProvider';
import { castPartId } from '../common/utils';
import { drawHotspotShape, HS_COLOR } from './utils';

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
    dispatch(
      setSelection(partId, choiceId, onSaveActivity, model.multiple ? 'multiple' : 'single'),
    );
  };

  const onClickHotspot = (hs: Hotspot) => {
    if (!isEvaluated(uiState)) {
      onSelect(partId, hs.id);
    }
  };

  const mapName = 'map' + model.choices[0].id;

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
        <ResetButtonConnected
          onReset={() => dispatch(resetAction(onResetActivity, { [partId]: [] }))}
        />
        <SubmitButtonConnected />
        <HintsDeliveryConnected partId={castPartId(activityState.parts[0].partId)} />
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class ImageHotspotDelivery extends DeliveryElement<ImageHotspotModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<ImageHotspotModelSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer);
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
