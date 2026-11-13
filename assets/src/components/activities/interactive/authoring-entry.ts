import { registerCreationFunc } from '../creation';
import manifest from './manifest.json';
import { defaultInteractiveModel } from './utils';

export { InteractiveAuthoring } from './InteractiveAuthoring';
export { InteractiveDelivery } from './InteractiveDelivery';

registerCreationFunc(manifest, () => Promise.resolve(defaultInteractiveModel()));
