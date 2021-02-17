import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import { DeliveryElement, DeliveryElementProps,
  EvaluationResponse, ResetActivityResponse, RequestHintResponse } from '../DeliveryElement';
import { ShortAnswerModelSchema, InputType } from './schema';
import * as ActivityTypes from '../types';
import { Stem } from '../common/DisplayedStem';
import { Hints } from '../common/DisplayedHints';
import { Reset } from '../common/Reset';
import { Evaluation } from '../common/Evaluation';
import { valueOr } from 'utils/common';

type Evaluation = {
  score: number,
  outOf: number,
  feedback: ActivityTypes.RichText,
};

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
      <input type="number"
        className="form-control"
        onChange={(e: any) => props.onChange(e.target.value)}
        value={input}
        disabled={props.isEvaluated} />
    );
  }
  if (props.inputType === 'text') {
    return (
      <input type="text"
        className="form-control"
        onChange={(e: any) => props.onChange(e.target.value)}
        value={input}
        disabled={props.isEvaluated} />
    );
  }
  return (
    <textarea
      rows={5}
      cols={80}
      className="form-control"
      onChange={(e: any) => props.onChange(e.target.value)}
      value={input}
      disabled={props.isEvaluated}>
    </textarea>
  );
};

const ShortAnswer = (props: DeliveryElementProps<ShortAnswerModelSchema>) => {

  const [model, setModel] = useState(props.model);
  const [attemptState, setAttemptState] = useState(props.state);
  const [hints, setHints] = useState(props.state.parts[0].hints);
  const [hasMoreHints, setHasMoreHints] = useState(props.state.parts[0].hasMoreHints);
  const [input, setInput] = useState(valueOr(attemptState.parts[0].response, ''));
  const { stem } = model;

  const isEvaluated = attemptState.score !== null;

  const onInputChange = (input: string) => {

    setInput(input);

    props.onSaveActivity(attemptState.attemptGuid,
      [{ attemptGuid: attemptState.parts[0].attemptGuid, response: { input } }]);
  };

  const onSubmit = () => {
    props.onSubmitActivity(attemptState.attemptGuid,
      [{ attemptGuid: attemptState.parts[0].attemptGuid, response: { input } }])
      .then((response: EvaluationResponse) => {
        if (response.evaluations.length > 0) {
          const { score, out_of, feedback, error } = response.evaluations[0];
          const parts = [Object.assign({}, attemptState.parts[0], { feedback, error })];
          const updated = Object.assign({}, attemptState, { score, outOf: out_of, parts });
          setAttemptState(updated);
        }
      });
  };

  const onRequestHint = () => {
    props.onRequestHint(attemptState.attemptGuid, attemptState.parts[0].attemptGuid)
    .then((state: RequestHintResponse) => {
      if (state.hint !== undefined) {
        setHints([...hints, state.hint] as any);
      }
      setHasMoreHints(state.hasMoreHints);
    });
  };

  const onReset = () => {
    props.onResetActivity(attemptState.attemptGuid)
    .then((state: ResetActivityResponse) => {
      setAttemptState(state.attemptState);
      setModel(state.model as ShortAnswerModelSchema);
      setHints([]);
      setHasMoreHints(props.state.parts[0].hasMoreHints);
      setInput('');
    });
  };

  const evaluationSummary = isEvaluated
    ? <Evaluation key="evaluation" attemptState={attemptState}/>
    : null;

  const reset = isEvaluated && !props.graded
    ? (<div className="d-flex">
        <div className="flex-fill"></div>
        <Reset hasMoreAttempts={attemptState.hasMoreAttempts} onClick={onReset} />
      </div>
    )
    : null;

  const ungradedDetails = props.graded ? null : [
    evaluationSummary,
    <Hints key="hints" onClick={onRequestHint} hints={hints}
      hasMoreHints={hasMoreHints} isEvaluated={isEvaluated}/>];

  const gradedDetails = props.graded && props.progress_state === 'in_review' ? [
    evaluationSummary] : null;

  const maybeSubmitButton = props.graded
  ? null
  : (
    <button
      className="btn btn-primary mt-2 float-right" disabled={isEvaluated} onClick={onSubmit}>
      Submit
    </button>
  );

  return (
    <div className="activity short-answer-activity">
      <div className="activity-content">
        <Stem stem={stem} />

        <div className="">
          <Input
            inputType={model.inputType}
            input={input}
            isEvaluated={isEvaluated}
            onChange={onInputChange}/>
          {maybeSubmitButton}
        </div>

        {ungradedDetails}
        {gradedDetails}
      </div>
      {reset}
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class ShortAnswerDelivery extends DeliveryElement<ShortAnswerModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<ShortAnswerModelSchema>) {
    ReactDOM.render(<ShortAnswer {...props} />, mountPoint);
  }
}

// Register the web component:
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, ShortAnswerDelivery);
