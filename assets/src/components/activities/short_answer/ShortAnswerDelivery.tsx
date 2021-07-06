import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import {
  DeliveryElement,
  DeliveryElementProps,
  DeliveryElementProvider,
  ResetActivityResponse,
  useDeliveryElementContext,
} from '../DeliveryElement';
import { InputType, ShortAnswerModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { valueOr } from 'utils/common';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDeliveryConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/gradedPoints/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/resetButton/ResetButtonConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submitButton/SubmitButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { Provider, useDispatch, useSelector } from 'react-redux';
import {
  ActivityDeliveryState,
  initializeState,
  isEvaluated,
  activityDeliverySlice,
} from 'data/content/activities/DeliveryState';
import { configureStore } from 'state/store';

export const store = configureStore({}, activityDeliverySlice.reducer);

type InputProps = {
  input: any;
  onChange: (input: any) => void;
  inputType: InputType;
  isEvaluated: boolean;
};

const Input = (props: InputProps) => {
  const input = props.input === null ? '' : props.input.input;

  if (props.inputType === 'numeric') {
    return (
      <input
        type="number"
        aria-label="answer submission textbox"
        className="form-control"
        onChange={(e: any) => props.onChange(e.target.value)}
        value={input}
        disabled={props.isEvaluated}
      />
    );
  }
  if (props.inputType === 'text') {
    return (
      <input
        type="text"
        aria-label="answer submission textbox"
        className="form-control"
        onChange={(e: any) => props.onChange(e.target.value)}
        value={input}
        disabled={props.isEvaluated}
      />
    );
  }
  return (
    <textarea
      aria-label="answer submission textbox"
      rows={5}
      cols={80}
      className="form-control"
      onChange={(e: any) => props.onChange(e.target.value)}
      value={input}
      disabled={props.isEvaluated}
    ></textarea>
  );
};

export const ShortAnswerComponent: React.FC = () => {
  const {
    model,
    state: activityState,
    onSaveActivity,
  } = useDeliveryElementContext<ShortAnswerModelSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  useEffect(() => {
    dispatch(initializeState(model, activityState));
  }, []);
  const [input, setInput] = useState(valueOr(attemptState.parts[0].response, ''));

  // First render initializes state
  if (!uiState.selectedChoices) {
    return null;
  }

  const evaluated = isEvaluated(uiState);

  const onInputChange = (input: string) => {
    setInput(input);

    props.onSaveActivity(attemptState.attemptGuid, [
      { attemptGuid: attemptState.parts[0].attemptGuid, response: { input } },
    ]);
  };

  const onReset = () => {
    props.onResetActivity(attemptState.attemptGuid).then((state: ResetActivityResponse) => {
      setAttemptState(state.attemptState);
      setModel(state.model as ShortAnswerModelSchema);
      setHints([]);
      setHasMoreHints(props.state.parts[0].hasMoreHints);
      setInput('');
    });
  };

  return (
    <div className={`activity cata-activity ${evaluated ? 'evaluated' : ''}`}>
      <div className="activity-content">
        <StemDeliveryConnected />
        <GradedPointsConnected />

        <Input
          inputType={model.inputType}
          input={input}
          isEvaluated={evaluated}
          onChange={onInputChange}
        />

        <ResetButtonConnected />
        <SubmitButtonConnected />
        <HintsDeliveryConnected />
        <EvaluationConnected />
      </div>
    </div>
  );

  // const [model, setModel] = useState(props.model);
  // const [attemptState, setAttemptState] = useState(props.state);
  // const [hints, setHints] = useState(props.state.parts[0].hints);
  // const [hasMoreHints, setHasMoreHints] = useState(props.state.parts[0].hasMoreHints);
  // const { stem } = model;

  // const isEvaluated = attemptState.score !== null;

  // const writerContext = defaultWriterContext({ sectionSlug: props.sectionSlug });

  // const evaluationSummary = isEvaluated ? (
  //   <Evaluation key="evaluation" attemptState={attemptState} context={writerContext} />
  // ) : null;

  // const reset =
  //   isEvaluated && !props.graded ? (
  //     <div className="d-flex">
  //       <div className="flex-fill"></div>
  //       <Reset hasMoreAttempts={attemptState.hasMoreAttempts} onClick={onReset} />
  //     </div>
  //   ) : null;

  // const ungradedDetails = props.graded
  //   ? null
  //   : [
  //       evaluationSummary,
  //       <Hints
  //         key="hints"
  //         onClick={onRequestHint}
  //         hints={hints}
  //         context={writerContext}
  //         hasMoreHints={hasMoreHints}
  //         isEvaluated={isEvaluated}
  //       />,
  //     ];

  // const gradedDetails = props.graded && props.review ? [evaluationSummary] : null;

  // const correctnessIcon = attemptState.score === 0 ? <Cross /> : <Checkmark />;

  // const gradedPoints =
  //   props.graded && props.review
  //     ? [
  //         <div key="correct" className="text-info font-italic">
  //           {correctnessIcon}
  //           <span>Points: </span>
  //           <span>{attemptState.score + ' out of ' + attemptState.outOf}</span>
  //         </div>,
  //       ]
  //     : null;

  // const maybeSubmitButton = props.graded ? null : (
  //   <button
  //     aria-label="submit"
  //     className="btn btn-primary mt-2 float-right"
  //     disabled={isEvaluated}
  //     onClick={onSubmit}
  //   >
  //     Submit
  //   </button>
  // );

  // return (
  //   <div className="activity short-answer-activity">
  //     <div className="activity-content">
  //       <Stem stem={stem} context={writerContext} />
  //       {gradedPoints}
  //       <div className="">
  //         <Input
  //           inputType={model.inputType}
  //           input={input}
  //           isEvaluated={isEvaluated}
  //           onChange={onInputChange}
  //         />
  //         {maybeSubmitButton}
  //       </div>

  //       {ungradedDetails}
  //       {gradedDetails}
  //     </div>
  //     {reset}
  //   </div>
  // );
};

// Defines the web component, a simple wrapper over our React component above
export class ShortAnswerDelivery extends DeliveryElement<ShortAnswerModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<ShortAnswerModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <ShortAnswerComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, ShortAnswerDelivery);
