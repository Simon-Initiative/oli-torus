// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');
import register from '../customElementWrapper';
import { customEvents as apiCustomEvents, observedAttributes as apiObservedAttributes, } from '../partsApi';
import FillBlanks from './FillBlanks';
const observedAttributes = [...apiObservedAttributes];
const customEvents = Object.assign({}, apiCustomEvents);
register(FillBlanks, manifest.delivery.element, observedAttributes, {
    customEvents,
    shadow: true,
});
//# sourceMappingURL=delivery-entry.js.map