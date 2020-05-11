import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { MultipleChoiceModelSchema, Stem } from './schema';
import { Choice } from 'components/activities/multiple_choice/schema';
import * as ActivityTypes from '../types';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { Maybe } from 'tsmonad';

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
}
const Choices = ({ choices, selected, onSelect }: ChoicesProps) => {
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
        index={index} />)}
    </div>
  );
};

interface ChoiceProps {
  choice: Choice;
  index: number;
  selected: boolean;
  onClick: () => void;
}
const Choice = ({ choice, index, selected, onClick }: ChoiceProps) => {
  return (
    <div key={choice.id}
      onClick={onClick}
      style={{
        display: 'inline-flex',
        alignItems: 'top',
        borderWidth: '2px 2px 4px',
        padding: '12px 16px',
        cursor: 'pointer',
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

interface HintsProps {

}
const Hints = ({}: HintsProps) => {
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
        <button className="btn btn-primary muted">Request Hint</button>
    </div>
  );
};

const MultipleChoice = (props: DeliveryElementProps<MultipleChoiceModelSchema>) => {
  const { stem, choices } = props.model;
  const { state } = props;

  const [selected, setSelected] = useState(
    state.parts[0].response === null
    ? Maybe.nothing<string>()
    : Maybe.just<string>(state.parts[0].response.input));

  const onSelect = (id: string) => {

    // Update local state
    setSelected(Maybe.just<string>(id));

    // Auto-save our student reponse
    props.onSave([{ attemptGuid: state.parts[0].attemptGuid, response: { input: id } }]);
  };

  return (
    <div style={{
      display: 'grid',
      flex: '1',
      alignItems: 'center',
      gridTemplateRows: 'min-content 1fr',
      gridGap: '8px',
    }}>
      <Stem stem={stem} />
      <Choices choices={choices} selected={selected} onSelect={onSelect}/>
      <Hints />
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
