export { MultipleChoiceDelivery } from './MultipleChoiceDelivery';
export { MultipleChoiceAuthoring } from './MultipleChoiceAuthoring';

import { Manifest, ActivityModelSchema, CreationContext } from '../types';
import { registerCreationFunc } from '../creation';
const manifest : Manifest = require('./manifest.json');

interface MultipleChoiceSchema extends ActivityModelSchema {
  stem: string;
  choices: string[];
  feedback: string[];
}

const model : MultipleChoiceSchema = {
  stem: '',
  choices: ['A', 'B', 'C', 'D'],
  feedback: ['A', 'B', 'C', 'D'],
};

function createFn(content: CreationContext) : Promise<MultipleChoiceSchema> {
  return Promise.resolve(model);
}

registerCreationFunc(manifest, createFn);
