export { FileUploadDelivery } from './FileUploadDelivery';
export { FileUploadAuthoring } from './FileUploadAuthoring';

// Registers the creation function:
import { Manifest, CreationContext } from '../types';
import { registerCreationFunc } from '../creation';
import { FileUploadSchema } from './schema';
import { defaultModel } from './utils';
// eslint-disable-next-line
const manifest: Manifest = require('./manifest.json');

function createFn(_context: CreationContext): Promise<FileUploadSchema> {
  return Promise.resolve(Object.assign({}, defaultModel()));
}

registerCreationFunc(manifest, createFn);
