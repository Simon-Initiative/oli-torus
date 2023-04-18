// Registers the creation function:
import { registerCreationFunc } from '../creation';
import { CreationContext, Manifest } from '../types';
import { MultiInputSchema } from './schema';
import { defaultModel } from './utils';

export { MultiInputDelivery } from './MultiInputDelivery';
export { MultiInputAuthoring } from './MultiInputAuthoring';

// eslint-disable-next-line
const manifest: Manifest = require('./manifest.json');

function createFn(_context: CreationContext): Promise<MultiInputSchema> {
  return Promise.resolve(Object.assign({}, defaultModel()));
}

registerCreationFunc(manifest, createFn);
