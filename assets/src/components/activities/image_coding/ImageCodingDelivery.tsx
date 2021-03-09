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
import { lastPart } from './utils';


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
  const [input, setInput] = useState(valueOr(model.starterCode, ''));
  const { stem, imageURLs } = model;
  // runtime evaluation state:
  let [output, setOutput] = useState('');
  let [error, setError] = useState('');

  const isEvaluated = attemptState.score !== null;

  const imageRefs = useRef<HTMLImageElement[]>(new Array(imageURLs.length));
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const canvasRef2 = useRef<HTMLCanvasElement>(null);
  const resultRef = useRef<HTMLCanvasElement>(null);
  const solnRef = useRef<HTMLCanvasElement>(null);

  // effect hook to initiate loading of images, executes once on first render
  useEffect( () => {
    imageURLs.map((url, i) => {
        const img = new Image();
        // Owing to a flaw in S3, we get CORS errors when image is loaded from cache if cached copy was obtained
        // from an earlier non-CORS request. Appending unique query string is a simple hack to force fresh load.
        // Downside: cache can fill up with many copies of same image.
        img.src = url + "?t=" + new Date().getTime();
        img.crossOrigin="anonymous";

        // save references in parallel array. Elements never need to be attached to DOM.
        imageRefs.current[i] = img;
      });
  }, []);

  const onInputChange = (input: string) => {

    setInput(input);

    props.onSaveActivity(attemptState.attemptGuid,
      [{ attemptGuid: attemptState.parts[0].attemptGuid, response: { input } }]);
  };

  const onSubmit = () => {
    const isCorrect = solutionCorrect();

    // get attributes for a ClientEvaluation
    const partState = attemptState.parts[0];
    const score = isCorrect ? 1 : 0;
    const outOf =  1; // partState.outOf;
    // FIXME: locate correct, error responses by score value (1 or 0)
    const feedback = isCorrect ? model.authoring.parts[0].responses[0].feedback
                               : model.authoring.parts[0].responses[1].feedback ;

    props.onSubmitEvaluations(attemptState.attemptGuid,
      [{attemptGuid: partState.attemptGuid, score, outOf, feedback }])
      .then((response: EvaluationResponse) => {
        if (response.evaluations.length > 0) {
          const { error } = response.evaluations[0];
          const parts = [Object.assign({}, partState, { feedback, error })];
          const updated = Object.assign({}, attemptState, { score, outOf, parts });
          setAttemptState(updated);
        }
      });
/*
    let pseudoResponse = isCorrect ? 'correct' : 'wrong';
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
      }); */
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

  var haveSolution = false;

  const solutionCorrect = () => {
    // evaluate solution code if needed to "print" result image to solnCanvas.
    // only needs to be done once.
    var solnCanvas = getResult(true);
    if (solnCanvas && ! haveSolution) {
      var ctx : EvalContext = { getCanvas, getImage, getResult, appendOutput, solutionRun: true};
      var e = Evaluator.execute(model.solutionCode, ctx);
      if (e != null) {
        updateError(e.message);
      } else {
        haveSolution = true;
      }
    }

    var diff = getResultDiff();
    console.log("Avg solution diff = " + diff);
    return diff < model.tolerance;
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

  var diff = 999;  // default if imageDiff throws size mismatch error
  try {
    diff = Evaluator.imageDiff(studentData, solnData));
  }
  finally {
    return diff;
  }
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

  const getCanvas = (n: number = 0) => {
     // we currently only need exactly two temp canvases, one for src and
     // one for destination of offscreen transformation.
     return n === 0 ? canvasRef.current : canvasRef2.current;
  }

  const getImage = (name: string) => {
    const i = imageURLs.findIndex(url => lastPart(url) === name);
    if (i < 0 || i >= imageRefs.current.length)
      return null;

    return imageRefs.current[i];
  }

  const getResult = (solution: boolean) => {
    return solution ? solnRef.current : resultRef.current;
  }

  const maybeSubmitButton = (model.isExample || props.graded)
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

        {/* implementation relies on 2 hidden canvases for image operations */}
         <canvas ref={canvasRef} style={{display: 'none'}}/>
         <canvas ref={canvasRef2} style={{display: 'none'}}/>

        <div style={{whiteSpace: 'pre-wrap'}}>
          <h5>Output:</h5>
          {renderOutput()}
          {errorMsg()}
          {/* output canvases for student and (hidden) correct solution */}
          <canvas ref={resultRef} height="0" width="0"/>
          <canvas ref={solnRef} style={{display: 'none'}} />
        </div>

        {!model.isExample && ungradedDetails}
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
