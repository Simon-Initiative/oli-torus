import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { MultipleChoiceModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Evaluation } from '../common/Evaluation';
import { IconCorrect, IconIncorrect } from 'components/misc/Icons';
import { defaultWriterContext } from 'data/content/writers/context';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import {
  ActivityDeliveryState,
  initializeState,
  isEvaluated,
  reset,
  selectChoice,
  slice,
  submit,
} from 'data/content/activities/DeliveryState';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { GradedPoints } from 'components/activities/common/GradedPoints';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { Radio } from 'components/activities/common/icons/Radio';
import { ResetButton } from 'components/activities/common/delivery/ResetButton';
import { SubmitButton } from 'components/activities/common/SubmitButton';
import { HintsDelivery } from 'components/activities/common/hints/delivery/HintsDelivery';
import { combineReducers } from 'redux';
import { requestHint } from 'data/content/activities/delivery/hintsState';

// export const store = configureStore({}, combineReducers({
//   slice.reducer}));
export const store = configureStore({}, slice.reducer);

export const MultipleChoiceComponent = (props: DeliveryElementProps<MultipleChoiceModelSchema>) => {
  const state = useSelector(
    (state: ActivityDeliveryState & { model: ActivityTypes.HasStem & ActivityTypes.HasChoices }) =>
      state,
  );
  const dispatch = useDispatch();

  useEffect(() => {
    dispatch(initializeState(props.model, props.state));
  }, []);

  // First render initializes state
  if (!state.model) {
    return null;
  }

  const {
    attemptState,
    model: { stem, choices },
    selectedChoices,
    hints,
    hasMoreHints,
  } = state;

  const writerContext = defaultWriterContext({ sectionSlug: props.sectionSlug });

  const isCorrect = attemptState.score !== 0;

  return (
    <div className={`activity mc-activity ${isEvaluated(state) ? 'evaluated' : ''}`}>
      <div className="activity-content">
        <StemDelivery stem={stem} context={writerContext} />
        <GradedPoints
          shouldShow={props.graded && props.review}
          icon={isCorrect ? <IconCorrect /> : <IconIncorrect />}
          attemptState={attemptState}
        />
        <ChoicesDelivery
          unselectedIcon={<Radio.Unchecked />}
          selectedIcon={
            !isEvaluated(state) ? (
              <Radio.Checked />
            ) : isCorrect ? (
              <Radio.Correct />
            ) : (
              <Radio.Incorrect />
            )
          }
          choices={choices}
          selected={selectedChoices}
          onSelect={(id) => dispatch(selectChoice(id, props.onSaveActivity))}
          isEvaluated={isEvaluated(state)}
          context={writerContext}
        />
        <ResetButton
          shouldShow={isEvaluated(state) && !props.graded}
          disabled={!attemptState.hasMoreAttempts}
          onClick={() => dispatch(reset(props.onResetActivity))}
        />
        <SubmitButton
          shouldShow={!isEvaluated(state) && !props.graded}
          disabled={selectedChoices.length === 0}
          onClick={() => dispatch(submit(props.onSubmitActivity))}
        />
        <HintsDelivery
          shouldShow={!isEvaluated(state) && !props.graded}
          onClick={() => dispatch(requestHint(props.onRequestHint))}
          hints={hints}
          hasMoreHints={hasMoreHints}
          isEvaluated={isEvaluated(state)}
          context={writerContext}
        />
        <Evaluation
          shouldShow={isEvaluated(state) && (!props.graded || props.review)}
          attemptState={attemptState}
          context={writerContext}
        />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class MultipleChoiceDelivery extends DeliveryElement<MultipleChoiceModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<MultipleChoiceModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <MultipleChoiceComponent {...props} />
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, MultipleChoiceDelivery);
