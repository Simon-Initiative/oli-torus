// Registers the creation function:
import { registerCreationFunc } from '../creation';
import { CreationContext, Manifest } from '../types';
import { ShortAnswerModelSchema } from './schema';
import { defaultModel } from './utils';

export { ShortAnswerDelivery } from './ShortAnswerDelivery';
export { ShortAnswerAuthoring } from './ShortAnswerAuthoring';

// eslint-disable-next-line
const manifest: Manifest = require('./manifest.json');

function createFn(_context: CreationContext): Promise<ShortAnswerModelSchema> {
  return Promise.resolve(Object.assign({}, defaultModel()));
}

registerCreationFunc(manifest, createFn);
