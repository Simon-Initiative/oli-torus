// Registers the creation function:
import { registerCreationFunc } from '../creation';
import { CreationContext, Manifest } from '../types';
import { ResponseMultiInputSchema } from './schema';
import { defaultModel } from './utils';

export { ResponseMultiInputDelivery } from './ResponseMultiInputDelivery';
export { ResponseMultiInputAuthoring } from './ResponseMultiInputAuthoring';

// eslint-disable-next-line
const manifest: Manifest = require('./manifest.json');

function createFn(_context: CreationContext): Promise<ResponseMultiInputSchema> {
  return Promise.resolve(Object.assign({}, defaultModel()));
}

registerCreationFunc(manifest, createFn);
