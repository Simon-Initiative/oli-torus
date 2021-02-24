import React, { useState, useEffect, useRef } from 'react';
import ReactDOM from 'react-dom';
import { DeliveryElement, DeliveryElementProps,
  EvaluationResponse, ResetActivityResponse, RequestHintResponse } from '../DeliveryElement';
import { ImageCodingModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Stem } from '../common/DisplayedStem';
import { Hints } from '../common/DisplayedHints';
import { Reset } from '../common/Reset';
import { Evaluation } from '../common/Evaluation';
import { valueOr } from 'utils/common';
import { Evaluator, EvalContext} from './Evaluator';
import { CSSTransition } from 'react-transition-group';


type Evaluation = {
  score: number,
  outOf: number,
  feedback: ActivityTypes.RichText,
};

type InputProps = {
  input: any;
  onChange: (input: any) => void;
  isEvaluated: boolean;
};

const Input = (props: InputProps) => {

  const input = props.input === null ? '' : props.input;

  return (
    <textarea
      rows={7}
      cols={80}
      className="form-control"
      onChange={(e: any) => props.onChange(e.target.value)}
      value={input}
      disabled={props.isEvaluated}/>
  );
};

export interface ImageCodingDeliveryProps extends DeliveryElementProps<ImageCodingModelSchema> {
  // output: string;
}

const ImageCoding = (props: ImageCodingDeliveryProps) => {

  const [model, setModel] = useState(props.model);
  const [attemptState, setAttemptState] = useState(props.state);
  const [hints, setHints] = useState(props.state.parts[0].hints);
  const [hasMoreHints, setHasMoreHints] = useState(props.state.parts[0].hasMoreHints);
  // const [input, setInput] = useState(valueOr(attemptState.parts[0].response, ''));
  const [input, setInput] = useState(valueOr(model.starterCode, ''));
  const { stem } = model;
  // runtime evaluation state:
  let [output, setOutput] = useState('');
  let [error, setError] = useState('');

  const isEvaluated = attemptState.score !== null;

  const imageRef = useRef<HTMLImageElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const resultRef = useRef<HTMLCanvasElement>(null);
  const solnRef = useRef<HTMLCanvasElement>(null);

  const onInputChange = (input: string) => {

    setInput(input);

    props.onSaveActivity(attemptState.attemptGuid,
      [{ attemptGuid: attemptState.parts[0].attemptGuid, response: { input } }]);
  };

  const onSubmit = () => {
    let pseudoResponse = solutionCorrect() ? 'correct' : 'wrong';
    console.log('Submitting response: ' + pseudoResponse);

    props.onSubmitActivity(attemptState.attemptGuid,
      [{ attemptGuid: attemptState.parts[0].attemptGuid, response: { input: pseudoResponse } }])
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
      setModel(state.model as ImageCodingModelSchema);
      setHints([]);
      setHasMoreHints(props.state.parts[0].hasMoreHints);
      setInput(model.starterCode);
      resetEval();
      // Reload starter code?
    });
  };

  const updateOutput = (s:string) => {
    // update local var so we can use it until next render
    output = s;
    setOutput(output);
  }

  const updateError = (s:string) => {
    // update local var so we can use it until next render
    error = s;
    setError(error);
  }

  const resetEval = () => {
    updateOutput('');
    updateError('');
    // collapse result canvas
    if (resultRef.current) {
      resultRef.current.width = 0;
      resultRef.current.height = 0
    }
  }

  const appendOutput = (s: string) => {
    updateOutput(output + s);
    console.log("Output now: |" + output + '|');
  }

  const onRun = () => {
    // clear output for new run
    resetEval();

    var ctx : EvalContext = { getCanvas, getImage, getResult, appendOutput, solutionRun: false};
    var e = Evaluator.execute(input, ctx);
    if (e != null) {
      updateError(e.message);
    }
  }

  const solutionCorrect = () => {
    // evaluate solution code if needed to "print" result image to solnCanvas.
    // only needs to be done once.
    var solnCanvas = getResult(true);
    if (solnCanvas && solnCanvas.width === 0) {}
      var ctx : EvalContext = { getCanvas, getImage, getResult, appendOutput, solutionRun: true};
      var e = Evaluator.execute(model.solutionCode, ctx);
      if (e != null) {
        updateError(e.message);
    }

    var diff = getResultDiff();
    console.log("Avg solution diff = " + diff);
    return diff < 1;
  }

// Computes and returns the image diff, or 999 for error.
// todo: structure error cases better.
function getResultDiff() {

  var studentCanvas = getResult(false);
  if (!studentCanvas) {
    console.log("error: no student canvas");
    return(999);
  }
  // width = 0 => student run failed or they didn't run at all. Can't getImageData
  if (studentCanvas.width === 0) {
    console.log("no student image to compare");
    return(999);
  }

  var solnCanvas = getResult(true);
  if (!solnCanvas) {
    console.log("error: no soln canvas");
    return(999);
  }
  if (solnCanvas.width === 0) {
    console.log("no solution image to compare");
    return(999);
  }

  var studentData = studentCanvas.getContext("2d")
      .getImageData(0, 0, studentCanvas.width, studentCanvas.height).data;

  var solnData = solnCanvas.getContext("2d")
      .getImageData(0, 0, solnCanvas.width, solnCanvas.height).data;

  return(Evaluator.imageDiff(studentData, solnData));
}

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

  const renderOutput = () => {
    if (!output) {
      return null
    }
    return <p>{output}</p>;
  }
  const errorMsg = () => {
    if (!error) {
      return null;
    }

    return <p><span style={{color: 'red'}}>Error: </span>{error}</p>
  }

  const initImageCanvas = (e: any) => {
    const canvas = canvasRef.current;
    const img = imageRef.current;

    if (img === null || canvas === null) {
      console.log("initCanvas: img or canvas is null")
      return;
    }

    const ctx = canvas.getContext("2d");
    ctx.canvas.width = img.width;
    ctx.canvas.height = img.height;
    ctx.drawImage(img, 0, 0);
  }

  const getCanvas = (id : string) => {
    return canvasRef.current;
  }

  const getImage = (name: string) => {
    return imageRef.current;
  }

  const getResult = (solution: boolean) => {
    return solution ? solnRef.current : resultRef.current;
  }

  const maybeSubmitButton = !model.isExample && props.graded
  ? null
  : (
    <button
      className="btn btn-primary mt-2 float-right" disabled={isEvaluated} onClick={onSubmit}>
      Submit
    </button>
  );

  const runButton  = (
    <button
      className="btn btn-primary mt-2 float-left" disabled={isEvaluated} onClick={onRun}>
      Run
    </button>
  )

  return (
    <div className="activity short-answer-activity">
      <div className="activity-content">
        <Stem stem={stem} />

        <div className="">
          <Input
            input={input}
            isEvaluated={isEvaluated}
            onChange={onInputChange}/>
          {runButton} {maybeSubmitButton}
        </div>

        <div>
          <img ref={imageRef} src={model.imageURL} onLoad={initImageCanvas} style={{display: 'none'}} crossOrigin="anonymous"/>
          <canvas ref={canvasRef} style={{display: 'none'}}/>
        </div>

        <div style={{whiteSpace: 'pre-wrap'}}>
          <h5>Output:</h5>
          {renderOutput()}
          {errorMsg()}
          <canvas ref={resultRef} height="0" width="0"/>
          <canvas ref={solnRef} style={{display: 'none'}}/>
        </div>

        {ungradedDetails}
      </div>
      {reset}
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class ImageCodingDelivery extends DeliveryElement<ImageCodingModelSchema> {
  render(mountPoint: HTMLDivElement, props: ImageCodingDeliveryProps) {
    ReactDOM.render(<ImageCoding {...props} />, mountPoint);
  }
}

// Register the web component:
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, ImageCodingDelivery);
