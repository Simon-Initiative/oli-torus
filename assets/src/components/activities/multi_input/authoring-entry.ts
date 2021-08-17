export { MultiInputDelivery } from './MultiInputDelivery';
export { MultiInputAuthoring } from './MultiInputAuthoring';

// Registers the creation function:
import { Manifest, CreationContext } from '../types';
import { registerCreationFunc } from '../creation';
import { MultiInputSchema } from './schema';
import { defaultModel } from './utils';
// eslint-disable-next-line
const manifest: Manifest = require('./manifest.json');

function createFn(_context: CreationContext): Promise<MultiInputSchema> {
  return Promise.resolve(Object.assign({}, defaultModel()));
}

registerCreationFunc(manifest, createFn);
