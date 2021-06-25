import { CheckAllThatApplyModelSchema } from 'components/activities/check_all_that_apply/schema';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { ResetButton } from 'components/activities/common/delivery/ResetButton';
import { Evaluation } from 'components/activities/common/Evaluation';
import { GradedPoints } from 'components/activities/common/GradedPoints';
import { HintsDelivery } from 'components/activities/common/hints/HintsDelivery';
import { Checkbox } from 'components/activities/common/icons/Checkbox';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { SubmitButton } from 'components/activities/common/SubmitButton';
import { HasChoices, HasStem, Manifest } from 'components/activities/types';
import { IconCorrect, IconIncorrect } from 'components/misc/Icons';
import {
  ActivityDeliveryState,
  initializeState,
  isEvaluated,
  requestHint,
  reset,
  selectChoice,
  slice,
  submit,
} from 'data/content/activities/DeliveryState';
import { defaultWriterContext } from 'data/content/writers/context';
import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';

export const store = configureStore({}, slice.reducer);

export const CheckAllThatApplyComponent = (
  props: DeliveryElementProps<CheckAllThatApplyModelSchema>,
) => {
  const state = useSelector(
    (state: ActivityDeliveryState & { model: HasStem & HasChoices }) => state,
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
    <div className={`activity cata-activity ${isEvaluated(state) ? 'evaluated' : ''}`}>
      <div className="activity-content">
        <StemDelivery stem={stem} context={writerContext} />
        <GradedPoints
          shouldShow={props.graded && props.review}
          icon={isCorrect ? <IconCorrect /> : <IconIncorrect />}
          attemptState={attemptState}
        />
        <ChoicesDelivery
          unselectedIcon={<Checkbox.Unchecked />}
          selectedIcon={
            !isEvaluated(state) ? (
              <Checkbox.Checked />
            ) : isCorrect ? (
              <Checkbox.Correct />
            ) : (
              <Checkbox.Incorrect />
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
          key="hints"
          onClick={() => dispatch(requestHint(props.onRequestHint))}
          hints={hints}
          hasMoreHints={hasMoreHints}
          isEvaluated={isEvaluated(state)}
          context={writerContext}
        />
        <Evaluation
          shouldShow={isEvaluated(state) && (!props.graded || props.review)}
          key="evaluation"
          attemptState={attemptState}
          context={writerContext}
        />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class CheckAllThatApplyDelivery extends DeliveryElement<CheckAllThatApplyModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<CheckAllThatApplyModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <CheckAllThatApplyComponent {...props} />
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.delivery.element, CheckAllThatApplyDelivery);
