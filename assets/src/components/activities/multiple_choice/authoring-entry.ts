// This is the entry point for the multiple choice authoring
// component, as specified in the manifest.json

// An authoring component entry point must expose the following
// three things:
//
// 1. The web component specified to use for authoring.
// 2. The web component specified to use for delivery. Delivery
//    component must be exposed to allow the resource editor to
//    operate activites of this type in 'test mode'
// 3. A 'creation function'.  A function that when invoked will
//    asynchronously delivery a new model instance for this
//    activity type. This is to allow the activity author to have
//    full control over populating a new activity.

// Fulfills 1. and 2. from above by exporting these components:
export { MultipleChoiceDelivery } from './MultipleChoiceDelivery';
export { MultipleChoiceAuthoring } from './MultipleChoiceAuthoring';

// Registers the creation function:
import { Manifest, CreationContext } from '../types';
import { registerCreationFunc } from '../creation';
import { MultipleChoiceModelSchema, Choice, RichText } from './schema';
import * as ContentModel from 'data/content/model';
import guid from 'utils/guid';
const manifest : Manifest = require('./manifest.json');

export function fromText(text: string): { id: number, content: RichText } {
  return {
    id: guid(),
    content: [
      ContentModel.create<ContentModel.Paragraph>({
        type: 'p',
        children: [{ text }],
        id: guid(),
      }),
    ],
  };
}

export const feedback = (text: string, match: string | number, score: number = 0) => ({
  ...fromText(text),
  match,
  score,
});


const defaultModel : () => MultipleChoiceModelSchema = () => {
  const choiceA: Choice = fromText('Choice A');
  const choiceB: Choice = fromText('Choice B');

  const feedbackA = feedback('Feedback A', choiceA.id, 1);
  const feedbackB = feedback('Feedback B', choiceB.id, 0);

  return {
    stem: fromText('Question Stem'),
    choices: [
      choiceA,
      choiceB,
    ],
    authoring: {
      feedback: [
        feedbackA,
        feedbackB,
      ],
      hints: [
        fromText('Deer in headlights hint'),
        fromText('Cognitive hint'),
        fromText('Bottom out hint'),
      ],
    },
  };
};

function createFn(content: CreationContext) : Promise<MultipleChoiceModelSchema> {
  return Promise.resolve(Object.assign({}, defaultModel()));
}

registerCreationFunc(manifest, createFn);
