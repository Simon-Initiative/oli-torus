// Registers the creation function:
import { registerCreationFunc } from '../creation';
import { CreationContext, Manifest } from '../types';
import { LTIExternalToolSchema } from './schema';

// This is the entry point for the lti external tool authoring
// component, as specified in the manifest.json

// An authoring component entry point must expose the following
// three things:
//
// 1. The web component specified to use for authoring.
// 2. The web component specified to use for delivery. Delivery
//    component must be exposed to allow the resource editor to
//    operate activites of this type in 'test mode'
// 3. A 'creation function'.  A function that when invoked will
//    asynchronously delivery a new model instance for this
//    activity type. This is to allow the activity author to have
//    full control over populating a new activity.

// Fulfills 1. and 2. from above by exporting these components:
export { LTIExternalToolDelivery } from './LTIExternalToolDelivery';
export { LTIExternalToolAuthoring } from './LTIExternalToolAuthoring';

// eslint-disable-next-line
const manifest: Manifest = require('./manifest.json');

function createFn(content: CreationContext): Promise<LTIExternalToolSchema> {
  return Promise.resolve({ openInNewTab: true, authoring: { parts: [] } });
}

registerCreationFunc(manifest, createFn);
