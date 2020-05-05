import React from 'react';
import ReactDOM from 'react-dom';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { MultipleChoiceModelSchema, Stem } from './schema';
import { Choice } from 'components/activities/multiple_choice/schema';
import * as ActivityTypes from '../types';
import { shuffle } from './utils';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
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
}
const Choices = ({ choices }: ChoicesProps) => {
  return (
    <div style={{
      display: 'grid',
      gridGap: '8px',
      gridTemplateColumns: '1fr',
    }}>
    {choices.map((choice, index) => <Choice choice={choice} index={index} />)}
    </div>
  );
};

interface ChoiceProps {
  choice: Choice;
  index: number;
}
const Choice = ({ choice, index }: ChoiceProps) => {
  return (
    <div key={choice.id}
      style={{
        display: 'inline-flex',
        alignItems: 'top',
        borderWidth: '2px 2px 4px',
        padding: '12px 16px',
        cursor: 'pointer',
        borderRadius: '16px',
        borderStyle: 'solid',
        borderColor: '#e5e5e5',
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

  return (
    <div style={{
      display: 'grid',
      flex: '1',
      alignItems: 'center',
      gridTemplateRows: 'min-content 1fr',
      gridGap: '8px',
    }}>
      <Stem stem={stem} />
      <Choices choices={shuffle(choices)} />
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
