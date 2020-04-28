import React from 'react';
import ReactDOM from 'react-dom';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { MultipleChoiceModelSchema } from './schema';
import { Choice } from 'components/activities/multiple_choice/schema';

// fisher-yates algo
function shuffle<T>(arr: T[]): T[] {
  // inclusive min, max
  const randomNumber = (min: number, max: number) =>
    Math.floor(Math.random() * (Math.floor(max) - Math.ceil(min) + 1)) + Math.ceil(min);

  const swap = (arr: T[], i: number, j: number) => {
    const temp = arr[i];
    arr[i] = arr[j];
    arr[j] = temp;
  };

  for (let i = arr.length - 1; i > 0; i -= 1) {
    swap(arr, i, randomNumber(0, i));
  }
  return arr;
}


const MultipleChoice = (props: DeliveryElementProps<MultipleChoiceModelSchema>) => {
  const choices = shuffle(props.model.choices);

  return (
    <div>
      <p className="question-stem"><b>Question</b></p>
      {choices.map((c, i) => <AnswerChoice choice={c} index={i} />)}
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class MultipleChoiceDelivery extends DeliveryElement<MultipleChoiceModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<MultipleChoiceModelSchema>) {
    ReactDOM.render(<MultipleChoice {...props} />, mountPoint);
  }
}

const AnswerChoice = ({ choice, index}: { choice: Choice, index: number }) => {
  return (
    <div
      style={{ display: 'flex', alignItems: 'center' }}
      key={choice.id}>
      <i className="material-icons">radio_button_unchecked</i> Answer Choice {index + 1}
    </div>
  );
};

// Register the web component:
import * as ActivityTypes from '../types';
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, MultipleChoiceDelivery);
