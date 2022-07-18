export { CustomDnDDelivery } from './CustomDnDDelivery';
export { CustomDnDAuthoring } from './CustomDnDAuthoring';

// Registers the creation function:
import { Manifest, CreationContext } from '../types';
import { registerCreationFunc } from '../creation';
import { CustomDnDSchema } from './schema';
import { defaultModel } from './utils';
// eslint-disable-next-line
const manifest: Manifest = require('./manifest.json');

function createFn(_context: CreationContext): Promise<CustomDnDSchema> {
  return Promise.resolve(Object.assign({}, defaultModel()));
}

registerCreationFunc(manifest, createFn);
