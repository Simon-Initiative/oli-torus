export { ShortAnswerDelivery } from './ShortAnswerDelivery';
export { ShortAnswerAuthoring } from './ShortAnswerAuthoring';
import { registerCreationFunc } from '../creation';
import { defaultModel } from './utils';
// eslint-disable-next-line
const manifest = require('./manifest.json');
function createFn(_context) {
    return Promise.resolve(Object.assign({}, defaultModel()));
}
registerCreationFunc(manifest, createFn);
//# sourceMappingURL=authoring-entry.js.map