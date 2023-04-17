// Registers the creation function:
import { registerCreationFunc } from '../creation';
import { CreationContext, Manifest } from '../types';
import { FileUploadSchema } from './schema';
import { defaultModel } from './utils';

export { FileUploadDelivery } from './FileUploadDelivery';
export { FileUploadAuthoring } from './FileUploadAuthoring';

// eslint-disable-next-line
const manifest: Manifest = require('./manifest.json');

function createFn(_context: CreationContext): Promise<FileUploadSchema> {
  return Promise.resolve(Object.assign({}, defaultModel()));
}

registerCreationFunc(manifest, createFn);
