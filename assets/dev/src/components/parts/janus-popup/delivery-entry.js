// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');
import register from '../customElementWrapper';
import { customEvents as apiCustomEvents, observedAttributes as apiObservedAttributes, } from '../partsApi';
import Popup from './Popup';
const observedAttributes = [...apiObservedAttributes];
const customEvents = Object.assign({}, apiCustomEvents);
register(Popup, manifest.delivery.element, observedAttributes, {
    customEvents,
    shadow: false,
    attrs: {
        model: {
            json: true,
        },
    },
});
//# sourceMappingURL=delivery-entry.js.map