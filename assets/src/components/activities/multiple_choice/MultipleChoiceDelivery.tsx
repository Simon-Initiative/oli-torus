import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import {
  DeliveryElement,
  DeliveryElementProps,
  EvaluationResponse,
  RequestHintResponse,
  ResetActivityResponse,
} from '../DeliveryElement';
import { MultipleChoiceModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { Maybe, writer } from 'tsmonad';
import { Stem } from '../common/DisplayedStem';
import { Hints } from '../common/DisplayedHints';
import { Reset } from '../common/Reset';
import { Evaluation } from '../common/Evaluation';
import { IconCorrect, IconIncorrect } from 'components/misc/Icons';
import { defaultWriterContext, WriterContext } from 'data/content/writers/context';

type Evaluation = {
  score: number,
  outOf: number,
  feedback: ActivityTypes.RichText,
};

interface ChoicesProps {
  choices: ActivityTypes.Choice[];
  selected: Maybe<string>;
  context: WriterContext;
  onSelect: (id: string) => void;
  isEvaluated: boolean;
}

const Choices = ({ choices, selected, context, onSelect, isEvaluated }: ChoicesProps) => {
  return (
    <div className="choices">
      {choices.map((choice, index) =>
        <Choice
          key={choice.id}
          onClick={() => onSelect(choice.id)}
          selected={selected.valueOr('') === choice.id}
          choice={choice}
          context={context}
          isEvaluated={isEvaluated}
          index={index} />)}
    </div>
  );
};

interface ChoiceProps {
  choice: ActivityTypes.Choice;
  index: number;
  selected: boolean;
  context: WriterContext;
  onClick: () => void;
  isEvaluated: boolean;
}

const Choice = ({ choice, index, selected, context, onClick, isEvaluated }: ChoiceProps) => {
  return (
    <div key={choice.id}
      onClick={isEvaluated ? undefined : onClick}
      className={`choice ${selected ? 'selected' : ''}`}>
      <span className="choice-index">{index + 1}</span>
      <HtmlContentModelRenderer text={choice.content} context={context} />
    </div>
  );
};

const MultipleChoice = (props: DeliveryElementProps<MultipleChoiceModelSchema>) => {

  const [model, setModel] = useState(props.model);
  const [attemptState, setAttemptState] = useState(props.state);
  const [hints, setHints] = useState(props.state.parts[0].hints);
  const [hasMoreHints, setHasMoreHints] = useState(props.state.parts[0].hasMoreHints);
  const [selected, setSelected] = useState(
    props.state.parts[0].response === null
      ? Maybe.nothing<string>()
      : Maybe.just<string>(props.state.parts[0].response.input));

  const { stem, choices } = model;

  const isEvaluated = attemptState.score !== null;

  const writerContext = defaultWriterContext({sectionSlug: props.sectionSlug});

  const onSelect = (id: string) => {
    // Update local state
    setSelected(Maybe.just<string>(id));

    if (props.graded) {

      // In summative context, post the student response to save it
      props.onSaveActivity(attemptState.attemptGuid,
        [{ attemptGuid: attemptState.parts[0].attemptGuid, response: { input: id } }]);

    } else {

      // Auto-submit our student reponse in formative context
      props.onSubmitActivity(attemptState.attemptGuid,
        [{ attemptGuid: attemptState.parts[0].attemptGuid, response: { input: id } }])
        .then((response: EvaluationResponse) => {
          if (response.evaluations.length > 0) {
            const { score, out_of, feedback, error } = response.evaluations[0];
            const parts = [Object.assign({}, attemptState.parts[0], { feedback, error })];
            const updated = Object.assign({}, attemptState, { score, outOf: out_of, parts });
            setAttemptState(updated);
          }
        });
    }
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
        setSelected(Maybe.nothing<string>());
        setAttemptState(state.attemptState);
        setModel(state.model as MultipleChoiceModelSchema);
        setHints([]);
        setHasMoreHints(props.state.parts[0].hasMoreHints);
      });
  };

  const evaluationSummary = isEvaluated
    ? <Evaluation key="evaluation" attemptState={attemptState} context={writerContext} />
    : null;

  const reset = isEvaluated && !props.graded
    ? (<div className="d-flex my-3">
      <div className="flex-fill"></div>
      <Reset hasMoreAttempts={attemptState.hasMoreAttempts} onClick={onReset} />
    </div>
    )
    : null;

  const ungradedDetails = props.graded ? null : [
    evaluationSummary,
    <Hints key="hints" onClick={onRequestHint} hints={hints}
      hasMoreHints={hasMoreHints} isEvaluated={isEvaluated} context={writerContext} />];

  const gradedDetails = props.graded && props.progressState === 'in_review' ? [
    evaluationSummary] : null;

  const correctnessIcon = attemptState.score === 0 ? <IconIncorrect /> : <IconCorrect />;

  const gradedPoints = props.graded && props.progressState === 'in_review' ? [
    <div className="text-info font-italic">
      {correctnessIcon}
      <span>Points: </span><span>{attemptState.score + ' out of '
    + attemptState.outOf}</span></div>] : null;

  return (
    <div className={`activity multiple-choice-activity ${isEvaluated ? 'evaluated' : ''}`}>
      <div className="activity-content">
        <Stem stem={stem} context={writerContext} />
        {gradedPoints}
        <Choices choices={choices} selected={selected}
          onSelect={onSelect} isEvaluated={isEvaluated} context={writerContext} />
        {ungradedDetails}
        {gradedDetails}
      </div>
      {reset}
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class MultipleChoiceDelivery extends DeliveryElement<MultipleChoiceModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<MultipleChoiceModelSchema>) {
    ReactDOM.render(<MultipleChoice {...props} />, mountPoint);
  }
}

// Register the web component:
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, MultipleChoiceDelivery);
