import React, { useState, useEffect, useRef } from 'react';
import ReactDOM from 'react-dom';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { LikertModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { defaultWriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import './LikertDelivery.scss';
import { StemDelivery } from '../common/stem/delivery/StemDelivery';
import { configureStore } from 'state/store';
import {
  activityDeliverySlice,
  ActivityDeliveryState,
  initializeState,
  setSelection,
  resetAction,
  PartInputs,
} from 'data/activities/DeliveryState';
import { Provider, useSelector, useDispatch } from 'react-redux';
import { initialPartInputs } from 'data/activities/utils';
import { SubmitButtonConnected } from '../common/delivery/submit_button/SubmitButtonConnected';
import { HintsDeliveryConnected } from '../common/hints/delivery/HintsDeliveryConnected';
import { EvaluationConnected } from '../common/delivery/evaluation/EvaluationConnected';
import { DEFAULT_PART_ID } from '../common/utils';
import { GradedPointsConnected } from '../common/delivery/graded_points/GradedPointsConnected';
import { ResetButtonConnected } from '../common/delivery/reset_button/ResetButtonConnected';
import { useDeliveryElementContext, DeliveryElementProvider } from '../DeliveryElementProvider';

const LikertComponent: React.FC = () => {
  const {
    state: activityState,
    onSaveActivity,
    onResetActivity,
    model,
    writerContext,
  } = useDeliveryElementContext<LikertModelSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  useEffect(() => {
    dispatch(initializeState(activityState, initialPartInputs(activityState)));
  }, []);

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  const isSelected = (partId: string, choiceId: string): boolean => {
    return uiState.partState[partId].studentInput[0] == choiceId;
  };

  const onChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const btn = event.currentTarget;
    const i = parseInt(btn.value);
    console.log('Changed ' + btn.name + ' value=' + btn.value + ' choiceId=' + model.choices[i].id);

    dispatch(setSelection(btn.name, model.choices[i].id, onSaveActivity, 'single'));
  };

  return (
    <div className="activity short-answer-activity">
      <div className="activity-content">
        <StemDelivery stem={model.stem} context={writerContext} />
        <table className="likertTable">
          <thead>
            <tr>
              <th></th>
              {model.choices.map((choice) => (
                <th align="center">
                  <HtmlContentModelRenderer content={choice.content} context={writerContext} />
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {model.items.map((item) => (
              <tr>
                <td>
                  <HtmlContentModelRenderer content={item.content} context={writerContext} />
                </td>
                {model.choices.map((choice, i) => (
                  <td align="center">
                    <input
                      type="radio"
                      value={i}
                      name={item.id}
                      onChange={onChange}
                      checked={isSelected(item.id, choice.id)}
                    />
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <GradedPointsConnected />
      <ResetButtonConnected
        onReset={() =>
          dispatch(
            resetAction(
              onResetActivity,
              model.items.reduce((acc, item) => {
                acc[item.id] = [''];
                return acc;
              }, {} as PartInputs),
            ),
          )
        }
      />
      <SubmitButtonConnected />
      <HintsDeliveryConnected partId={DEFAULT_PART_ID} />
      <EvaluationConnected />
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class LikertDelivery extends DeliveryElement<LikertModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<LikertModelSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer);
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <LikertComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, LikertDelivery);
