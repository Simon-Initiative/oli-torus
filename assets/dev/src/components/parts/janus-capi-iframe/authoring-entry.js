/* eslint-disable @typescript-eslint/no-var-requires */
const manifest = require('./manifest.json');
import register from '../customElementWrapper';
import { authoringObservedAttributes, customEvents as apiCustomEvents, observedAttributes as apiObservedAttributes, } from '../partsApi';
import CapiIframeAuthor from './CapiIframeAuthor';
import { adaptivitySchema, createSchema, getCapabilities, schema, uiSchema } from './schema';
const observedAttributes = [...apiObservedAttributes, ...authoringObservedAttributes];
const customEvents = Object.assign(Object.assign({}, apiCustomEvents), { onConfigure: 'configure', onSaveConfigure: 'saveconfigure', onCancelConfigure: 'cancelconfigure' });
register(CapiIframeAuthor, manifest.authoring.element, observedAttributes, {
    customEvents,
    shadow: false,
    attrs: {
        model: {
            json: true,
        },
    },
    customApi: {
        getSchema: () => schema,
        getUiSchema: () => uiSchema,
        createSchema,
        getCapabilities,
        getAdaptivitySchema: adaptivitySchema,
    },
});
//# sourceMappingURL=authoring-entry.js.map