import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import { DeliveryElement, DeliveryElementProps,
  EvaluationResponse, ResetActivityResponse, RequestHintResponse } from '../DeliveryElement';
import { MultipleChoiceModelSchema, Stem } from './schema';
import { Choice } from 'components/activities/multiple_choice/schema';
import * as ActivityTypes from '../types';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { Maybe } from 'tsmonad';

type Evaluation = {
  score: number,
  outOf: number,
  feedback: ActivityTypes.RichText,
};

interface StemProps {
  stem: Stem;
}
const Stem = ({ stem }: StemProps) => {
  return (
    <HtmlContentModelRenderer text={stem.content} />
  );
};

interface ChoicesProps {
  choices: Choice[];
  selected: Maybe<string>;
  onSelect: (id: string) => void;
  isEvaluated: boolean;
}
const Choices = ({ choices, selected, onSelect, isEvaluated }: ChoicesProps) => {
  return (
    <div style={{
      display: 'grid',
      gridGap: '8px',
      gridTemplateColumns: '1fr',
    }}>
    {choices.map((choice, index) =>
      <Choice
        onClick={() => onSelect(choice.id)}
        selected={selected.valueOr('') === choice.id}
        choice={choice}
        isEvaluated={isEvaluated}
        index={index} />)}
    </div>
  );
};

interface ChoiceProps {
  choice: Choice;
  index: number;
  selected: boolean;
  onClick: () => void;
  isEvaluated: boolean;
}
const Choice = ({ choice, index, selected, onClick, isEvaluated }: ChoiceProps) => {
  return (
    <div key={choice.id}
      onClick={isEvaluated ? undefined : onClick}
      style={{
        display: 'inline-flex',
        alignItems: 'top',
        borderWidth: '2px 2px 4px',
        padding: '12px 16px',
        cursor: isEvaluated ? 'arrow' : 'pointer',
        borderRadius: '16px',
        borderStyle: 'solid',
        borderColor: '#e5e5e5',
        backgroundColor: selected ? 'lightblue' : 'transparent',
      }}>
        <span style={{
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          border: '2px solid #e5e5e5',
          borderRadius: '8px',
          color: '#afafaf',
          height: '30px',
          width: '30px',
          fontWeight: 'bold',
          marginRight: '16px',
        }}>{index + 1}</span>
      <HtmlContentModelRenderer text={choice.content} />
    </div>
  );
};

interface DisplayedHintProps {
  hint: ActivityTypes.Hint;
}

const DisplayedHint = ({ hint }: DisplayedHintProps) => {
  return (
    <div key={hint.id}
      style={{
        display: 'inline-flex',
        alignItems: 'top',
        borderWidth: '2px 2px 4px',
        padding: '12px 16px',
        borderRadius: '16px',
        borderStyle: 'solid',
        borderColor: '#e5e5e5',
        backgroundColor: 'transparent',
      }}>
      <HtmlContentModelRenderer text={hint.content} />
    </div>
  );
};


interface HintsProps {
  isEvaluated: boolean;
  hints: ActivityTypes.Hint[];
  hasMoreHints: boolean;
  onClick: () => void;
}
const Hints = (props: HintsProps) => {
  return (
    <div className="question-hints" style={{
      padding: '16px',
      border: '1px solid rgba(34,36,38,.15)',
      borderRadius: '5px',
      boxShadow: '0 1px 2px 0 rgba(34,36,38,.15)',
      position: 'relative',
    }}>
      <div style={{
        position: 'absolute',
        left: '0',
        bottom: '-3px',
        borderTop: '1px solid rgba(34,36,38,.15)',
        height: '6px',
        width: '100%',
      }}></div>
        <h6><b>Hints</b></h6>
        <div style={{
          display: 'grid',
          flex: '1',
          alignItems: 'center',
          gridTemplateRows: 'min-content 1fr',
          gridGap: '8px',
        }}>
          {props.hints.map(hint => <DisplayedHint hint={hint}/>)}
        </div>
        <button
          onClick={props.onClick}
          disabled={props.isEvaluated || !props.hasMoreHints}
          className="btn btn-primary muted">Request Hint</button>
    </div>
  );
};

const Evaluation = ({ attemptState } : { attemptState : ActivityTypes.ActivityState}) => {

  const { score, outOf, parts } = attemptState;
  const feedback = parts[0].feedback.content;

  let backgroundColor = '#f0b4b4';
  if (score === outOf) {
    backgroundColor = '#a7e695';
  } else if ((score as number) > 0) {
    backgroundColor = '#f0e8b4';
  }

  return (
    <div key="evaluation"
      style={{
        display: 'inline-flex',
        alignItems: 'top',
        borderWidth: '2px 2px 4px',
        padding: '12px 16px',
        borderRadius: '2px',
        borderStyle: 'none',
        backgroundColor,
      }}>
        <span style={{
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          border: '2px solid #e5e5e5',
          borderRadius: '8px',
          color: '#afafaf',
          height: '30px',
          width: '60px',
          fontWeight: 'bold',
          marginRight: '16px',
        }}>{score + ' / ' + outOf}</span>
      <HtmlContentModelRenderer text={feedback} />
    </div>
  );

};

const Reset = ({ onClick } : { onClick : () => void}) =>
  <button onClick={onClick} className="btn btn-primary muted">Retry</button>;

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

  const onSelect = (id: string) => {

    // Update local state
    setSelected(Maybe.just<string>(id));

    // Auto-submit our student reponse
    props.onSubmitActivity(attemptState.attemptGuid,
      [{ attemptGuid: attemptState.parts[0].attemptGuid, response: { input: id } }])
      .then((response: EvaluationResponse) => {
        if (response.evaluations.length > 0) {
          const { score, out_of, feedback } = response.evaluations[0];
          const parts = [Object.assign({}, attemptState.parts[0], { feedback })];
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
      setSelected(Maybe.nothing<string>());
      setAttemptState(state.attemptState);
      setModel(state.model as MultipleChoiceModelSchema);
      setHints([]);
      setHasMoreHints(props.state.parts[0].hasMoreHints);
    });
  };

  const evaluationSummary = isEvaluated ? <Evaluation attemptState={attemptState}/> : null;
  const reset = isEvaluated ? <div className="float-right"><Reset onClick={onReset} /></div> : null;

  return (
    <div>
      <div style={{
        display: 'grid',
        flex: '1',
        alignItems: 'center',
        gridTemplateRows: 'min-content 1fr',
        gridGap: '8px',
      }}>
        <Stem stem={stem} />
        <Choices choices={choices} selected={selected}
          onSelect={onSelect} isEvaluated={isEvaluated}/>
        {evaluationSummary}
        <Hints onClick={onRequestHint} hints={hints}
          hasMoreHints={hasMoreHints} isEvaluated={isEvaluated}/>
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
