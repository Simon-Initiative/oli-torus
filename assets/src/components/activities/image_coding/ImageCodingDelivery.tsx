import React, { useEffect, useRef, useState } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useSelector } from 'react-redux';
import { maybe } from 'tsmonad';
import { Checkmark } from 'components/misc/icons/Checkmark';
import { Cross } from 'components/misc/icons/Cross';
import { activityDeliverySlice } from 'data/activities/DeliveryState';
import { isCorrect } from 'data/activities/utils';
import { defaultWriterContext } from 'data/content/writers/context';
import * as Events from 'data/events';
import { configureStore } from 'state/store';
import {
  DeliveryElement,
  DeliveryElementProps,
  EvaluationResponse,
  RequestHintResponse,
  ResetActivityResponse,
} from '../DeliveryElement';
import { DeliveryElementProvider } from '../DeliveryElementProvider';
import { Hints } from '../common/DisplayedHints';
import { Stem } from '../common/DisplayedStem';
import { Reset } from '../common/Reset';
import { Evaluation } from '../common/delivery/evaluation/Evaluation';
import { GradedPoints } from '../common/delivery/graded_points/GradedPoints';
import * as ActivityTypes from '../types';
import { EvalContext, Evaluator } from './Evaluator';
import { ImageCodingModelSchema } from './schema';
import { ImageCodeEditor } from './sections/ImageCodeEditor';
import { lastPart } from './utils';

type Evaluation = {
  score: number;
  outOf: number;
  feedback: ActivityTypes.RichText;
};

const listenForParentSurveySubmit = (
  surveyId: string | null,
  onRun: () => void,
  onSubmit: () => void,
) =>
  maybe(surveyId).lift((surveyId) =>
    // listen for survey submit events if the delivery element is in a survey
    document.addEventListener(
      Events.Registry.SurveySubmit,
      (e: CustomEvent<Events.SurveyDetails>) => {
        // check if this activity belongs to the survey being submitted
        if (e.detail.id === surveyId) {
          onRun();
          onSubmit();
        }
      },
    ),
  );

const listenForParentSurveyReset = (surveyId: string | null, onReset: () => void) =>
  maybe(surveyId).lift((surveyId) =>
    // listen for survey submit events if the delivery element is in a survey
    document.addEventListener(
      Events.Registry.SurveyReset,
      (e: CustomEvent<Events.SurveyDetails>) => {
        // check if this activity belongs to the survey being reset
        if (e.detail.id === surveyId) {
          onReset();
        }
      },
    ),
  );

// eslint-disable-next-line
export interface ImageCodingDeliveryProps extends DeliveryElementProps<ImageCodingModelSchema> {
  // output: string;
}

const ImageCoding = (props: ImageCodingDeliveryProps) => {
  const [model, setModel] = useState(props.model);
  const [attemptState, setAttemptState] = useState(props.state);
  const [hints, setHints] = useState(props.state.parts[0].hints);
  const [hasMoreHints, setHasMoreHints] = useState(props.state.parts[0].hasMoreHints);
  const [input, setInput] = useState(
    attemptState.parts[0].response ? attemptState.parts[0].response.input : model.starterCode,
  );
  const { stem, resourceURLs } = model;
  // runtime evaluation state:
  const [output, setOutput] = useState('');
  const [error, setError] = useState('');
  const [ranCode, setRanCode] = useState(false);
  let currentOutput = output;

  const isEvaluated = attemptState.score !== null;

  const writerContext = defaultWriterContext({
    graded: props.context.graded,
    sectionSlug: props.context.sectionSlug,
    bibParams: props.context.bibParams,
  });

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
    listenForParentSurveySubmit(props.context.surveyId, onRun, onSubmit);
    listenForParentSurveyReset(props.context.surveyId, onReset);

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
          const parts = [Object.assign({}, partState, { feedback, error, score, outOf })];
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
      setRanCode(false);
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

    setRanCode(true);
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
    return diff < model.tolerance;
  };

  const maybeResetButton = isEvaluated && !props.context.graded && !props.context.surveyId && (
    <div className="d-flex">
      <div className="flex-fill"></div>
      <Reset hasMoreAttempts={attemptState.hasMoreAttempts} onClick={onReset} />
    </div>
  );

  const maybeEvaluation = (
    <Evaluation
      shouldShow={
        !model.isExample &&
        isEvaluated &&
        (!props.context.graded || props.mode === 'review') &&
        props.context.showFeedback === true &&
        props.context.surveyId === null
      }
      key="evaluation"
      attemptState={attemptState}
      context={writerContext}
    />
  );

  const maybeGradedPoints = (
    <GradedPoints
      shouldShow={
        !model.isExample &&
        isEvaluated &&
        (!props.context.graded || props.mode === 'review') &&
        props.context.showFeedback === true &&
        props.context.surveyId === null
      }
      icon={isCorrect(attemptState) ? <Checkmark /> : <Cross />}
      attemptState={attemptState}
    />
  );

  const maybeHints = !model.isExample && props.context.graded && (
    <Hints
      key="hints"
      onClick={onRequestHint}
      hints={hints}
      context={writerContext}
      hasMoreHints={hasMoreHints}
      isEvaluated={isEvaluated}
    />
  );

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

  const maybeSubmitButton = !model.isExample && !props.context.surveyId && (
    <button
      className="btn btn-primary mt-2 float-right"
      disabled={isEvaluated || !ranCode}
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
        {maybeGradedPoints}
        <div>
          <ImageCodeEditor value={input} disabled={isEvaluated} onChange={onInputChange} />
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

        {maybeEvaluation}
        {maybeHints}
      </div>
      {maybeResetButton}
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class ImageCodingDelivery extends DeliveryElement<ImageCodingModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<ImageCodingModelSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer, {
      name: 'ImageCodingDelivery',
    });

    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <ImageCoding {...props} />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, ImageCodingDelivery);
