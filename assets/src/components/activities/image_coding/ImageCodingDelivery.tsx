import React, { useState, useEffect, useRef } from 'react';
import ReactDOM from 'react-dom';
import {
  DeliveryElement,
  DeliveryElementProps,
  EvaluationResponse,
  ResetActivityResponse,
  RequestHintResponse,
} from '../DeliveryElement';
import { ImageCodingModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Stem } from '../common/DisplayedStem';
import { Hints } from '../common/DisplayedHints';
import { Reset } from '../common/Reset';
import { Evaluation } from '../common/Evaluation';
import { valueOr } from 'utils/common';
import { Evaluator, EvalContext } from './Evaluator';
import { lastPart } from './utils';
import { defaultWriterContext } from 'data/content/writers/context';

type Evaluation = {
  score: number;
  outOf: number;
  feedback: ActivityTypes.RichText;
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
      disabled={props.isEvaluated}
    />
  );
};
// eslint-disable-next-line
export interface ImageCodingDeliveryProps extends DeliveryElementProps<ImageCodingModelSchema> {
  // output: string;
}

const ImageCoding = (props: ImageCodingDeliveryProps) => {
  const [model, setModel] = useState(props.model);
  const [attemptState, setAttemptState] = useState(props.state);
  const [hints, setHints] = useState(props.state.parts[0].hints);
  const [hasMoreHints, setHasMoreHints] = useState(props.state.parts[0].hasMoreHints);
  const [input, setInput] = useState(valueOr(model.starterCode, ''));
  const { stem, resourceURLs } = model;
  // runtime evaluation state:
  const [output, setOutput] = useState('');
  const [error, setError] = useState('');
  let currentOutput = output;

  const isEvaluated = attemptState.score !== null;

  const writerContext = defaultWriterContext({ sectionSlug: props.sectionSlug });

  // tslint:disable-next-line:prefer-array-literal
  const resourceRefs = useRef<(HTMLImageElement | string)[]>(new Array(resourceURLs.length));
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const canvasRef2 = useRef<HTMLCanvasElement>(null);
  const resultRef = useRef<HTMLCanvasElement>(null);
  const solnRef = useRef<HTMLCanvasElement>(null);

  const loadCSV = (url: string, i: number) => {
    fetch(url, { mode: 'cors' })
      .then((resp) => {
        if (!resp.ok) {
          throw new Error('failed to load ' + lastPart(url) + ': ' + resp.statusText);
        }
        return resp.text();
      })
      .then((text) => (resourceRefs.current[i] = text))
      .catch((e) => {
        throw new Error('failed to load ' + lastPart(url) + ': ' + e);
      });
  };

  const loadImage = (url: string, i: number) => {
    const img = new Image();
    // Owing to a flaw in S3, we get CORS errors when image is loaded from cache if cached
    // copy was obtainedf rom an earlier non-CORS request. Appending unique query string is
    // a simple hack to force fresh load.
    img.src = url + '?t=' + new Date().getTime();
    img.crossOrigin = 'anonymous';

    // save references in parallel array. Elements never need to be attached to DOM.
    resourceRefs.current[i] = img;
  };

  // effect hook to initiate fetching of resources, executes once on first render
  useEffect(() => {
    resourceURLs.map((url, i) => {
      url.endsWith('csv') ? loadCSV(url, i) : loadImage(url, i);
    });
  }, []);

  const onInputChange = (input: string) => {
    setInput(input);

    props.onSaveActivity(attemptState.attemptGuid, [
      { attemptGuid: attemptState.parts[0].attemptGuid, response: { input } },
    ]);
  };

  const onSubmit = () => {
    const isCorrect = solutionCorrect();

    // get attributes for a ClientEvaluation
    const score = isCorrect ? 1 : 0;
    const outOf = 1;
    const feedback = model.feedback[score];

    const partState = attemptState.parts[0];
    props
      .onSubmitEvaluations(attemptState.attemptGuid, [
        { attemptGuid: partState.attemptGuid, score, outOf, feedback, response: { input } },
      ])
      .then((response: EvaluationResponse) => {
        if (response.actions.length > 0) {
          const action: ActivityTypes.FeedbackAction = response
            .actions[0] as ActivityTypes.FeedbackAction;
          const { error } = action;
          const parts = [Object.assign({}, partState, { feedback, error })];
          const updated = Object.assign({}, attemptState, { score, outOf, parts });
          setAttemptState(updated);
        }
      });
  };

  const onRequestHint = () => {
    props
      .onRequestHint(attemptState.attemptGuid, attemptState.parts[0].attemptGuid)
      .then((state: RequestHintResponse) => {
        if (state.hint !== undefined) {
          setHints([...hints, state.hint] as any);
        }
        setHasMoreHints(state.hasMoreHints);
      });
  };

  const onReset = () => {
    props.onResetActivity(attemptState.attemptGuid).then((state: ResetActivityResponse) => {
      setAttemptState(state.attemptState);
      setModel(state.model as ImageCodingModelSchema);
      setHints([]);
      setHasMoreHints(props.state.parts[0].hasMoreHints);
      // Do we want reset to reload starter code, discarding changes?
      // setInput(model.starterCode);
      clearOutput();
    });
  };

  const updateOutput = (s: string) => {
    // update local var so we can use it until next render
    currentOutput = s;
    setOutput(s);
  };

  const clearOutput = () => {
    updateOutput('');
    setError('');
    // collapse result canvas
    if (resultRef.current) {
      resultRef.current.width = 0;
      resultRef.current.height = 0;
    }
  };

  const appendOutput = (s: string) => {
    updateOutput(currentOutput + s);
  };

  const onRun = () => {
    // clear output for new run
    clearOutput();

    const ctx: EvalContext = {
      getCanvas,
      getResource,
      getResult,
      appendOutput,
      solutionRun: false,
    };
    const e = Evaluator.execute(input, ctx);
    if (e != null) {
      setError(e.message);
    }
  };

  const usesImages = () => {
    return resourceURLs.some((url) => !url.endsWith('csv'));
  };

  const solutionCorrect = () => {
    return usesImages() ? imageCorrect() : textCorrect();
  };

  const textCorrect = () => {
    return new RegExp(model.regex).test(output);
  };

  const imageCorrect = () => {
    // evaluate solution code if needed to "print" result image to solnCanvas.
    // only needs to be done once, setting solnCanvas.width > 0
    const ctx: EvalContext = {
      getCanvas,
      getResource,
      getResult,
      appendOutput,
      solutionRun: true,
    };
    const solnCanvas = getResult(true);
    if (solnCanvas && solnCanvas.width === 0) {
      const e = Evaluator.execute(model.solutionCode, ctx);
      if (e != null) {
        setError(e.message);
      }
    }

    const diff = Evaluator.getResultDiff(ctx);
    // console.log('Avg solution diff = ' + diff);
    return diff < model.tolerance;
  };

  const evaluationSummary = isEvaluated ? (
    <Evaluation key="evaluation" attemptState={attemptState} context={writerContext} />
  ) : null;

  const reset =
    isEvaluated && !props.graded ? (
      <div className="d-flex">
        <div className="flex-fill"></div>
        <Reset hasMoreAttempts={attemptState.hasMoreAttempts} onClick={onReset} />
      </div>
    ) : null;

  const ungradedDetails = props.graded
    ? null
    : [
      evaluationSummary,
      <Hints
        key="hints"
        onClick={onRequestHint}
        hints={hints}
        context={writerContext}
        hasMoreHints={hasMoreHints}
        isEvaluated={isEvaluated}
      />,
    ];

  const renderOutput = () => {
    if (output === '') {
      return null;
    }
    return <p>{output}</p>;
  };

  const errorMsg = () => {
    if (!error) {
      return null;
    }

    return (
      <p>
        <span style={{ color: 'red' }}>Error: </span>
        {error}
      </p>
    );
  };

  const getCanvas = (n = 0) => {
    // we currently only need exactly two temp canvases, one for src and
    // one for destination of offscreen transformation.
    return n === 0 ? canvasRef.current : canvasRef2.current;
  };

  const getResource = (name: string) => {
    const i = resourceURLs.findIndex((url) => lastPart(url) === name);
    if (i < 0 || i >= resourceRefs.current.length) {
      return null;
    }

    return resourceRefs.current[i];
  };

  const getResult = (solution: boolean) => {
    return solution ? solnRef.current : resultRef.current;
  };

  const maybeSubmitButton =
    model.isExample || props.graded ? null : (
      <button
        className="btn btn-primary mt-2 float-right"
        disabled={isEvaluated}
        onClick={onSubmit}
      >
        Submit
      </button>
    );

  const runButton = (
    <button className="btn btn-primary mt-2 float-left" disabled={isEvaluated} onClick={onRun}>
      Run
    </button>
  );

  return (
    <div className="activity short-answer-activity">
      <div className="activity-content">
        <Stem stem={stem} context={writerContext} />

        <div className="">
          <Input input={input} isEvaluated={isEvaluated} onChange={onInputChange} />
          {runButton} {maybeSubmitButton}
        </div>

        {/* implementation relies on 2 hidden canvases for image operations */}
        <canvas ref={canvasRef} style={{ display: 'none' }} />
        <canvas ref={canvasRef2} style={{ display: 'none' }} />

        <div style={{ whiteSpace: 'pre-wrap' }}>
          <h5>Output:</h5>
          {renderOutput()}
          {errorMsg()}
          {/* output canvases for student and (hidden) correct solution */}
          <canvas ref={resultRef} height="0" width="0" />
          <canvas ref={solnRef} style={{ display: 'none' }} height="0" width="0" />
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
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, ImageCodingDelivery);
