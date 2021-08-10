export { DropdownDelivery } from './DropdownDelivery';
export { DropdownAuthoring } from './DropdownAuthoring';

// Registers the creation function:
import { Manifest, CreationContext } from '../types';
import { registerCreationFunc } from '../creation';
import { DropdownModelSchema } from './schema';
import { defaultModel } from './utils';
// eslint-disable-next-line
const manifest: Manifest = require('./manifest.json');

function createFn(content: CreationContext): Promise<DropdownModelSchema> {
  return Promise.resolve(Object.assign({}, defaultModel()));
}

registerCreationFunc(manifest, createFn);
