export { ShortAnswerDelivery } from './ShortAnswerDelivery';
export { ShortAnswerAuthoring } from './ShortAnswerAuthoring';

// Registers the creation function:
import { Manifest, CreationContext } from '../types';
import { registerCreationFunc } from '../creation';
import { ShortAnswerModelSchema } from './schema';
import { defaultModel } from './utils';
// eslint-disable-next-line
const manifest: Manifest = require('./manifest.json');

function createFn(content: CreationContext): Promise<ShortAnswerModelSchema> {
  return Promise.resolve(Object.assign({}, defaultModel()));
}

registerCreationFunc(manifest, createFn);
