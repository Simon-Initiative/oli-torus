// Registers the creation function:
import { registerCreationFunc } from '../creation';
import { CreationContext, Manifest } from '../types';
import { CustomDnDSchema } from './schema';
import { defaultModel } from './utils';

export { CustomDnDDelivery } from './CustomDnDDelivery';
export { CustomDnDAuthoring } from './CustomDnDAuthoring';

// eslint-disable-next-line
const manifest: Manifest = require('./manifest.json');

function createFn(_context: CreationContext): Promise<CustomDnDSchema> {
  return Promise.resolve(Object.assign({}, defaultModel()));
}

registerCreationFunc(manifest, createFn);
