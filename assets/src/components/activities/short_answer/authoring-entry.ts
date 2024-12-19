// Registers the creation function:
import { registerCreationFunc } from '../creation';
import { CreationContext, Manifest } from '../types';
import { ShortAnswerModelSchema } from './schema';
import { defaultModel, sAModel } from './utils';

export { ShortAnswerDelivery } from './ShortAnswerDelivery';
export { ShortAnswerAuthoring } from './ShortAnswerAuthoring';

// eslint-disable-next-line
const manifest: Manifest = require('./manifest.json');

function createFn(context: CreationContext): Promise<ShortAnswerModelSchema> {
  if (context && context.creationData) {
    return Promise.resolve(Object.assign({}, sAModel(context.creationData)));
  }
  return Promise.resolve(Object.assign({}, defaultModel()));
}

registerCreationFunc(manifest, createFn);
