/* eslint-disable @typescript-eslint/no-var-requires */
const manifest = require('./manifest.json');
import register from '../customElementWrapper';
import { customEvents as apiCustomEvents, observedAttributes as apiObservedAttributes, } from '../partsApi';
import FIBAuthor from './FIBAuthor';
import { adaptivitySchema, createSchema, schema, uiSchema } from './schema';
const observedAttributes = [...apiObservedAttributes];
const customEvents = Object.assign({}, apiCustomEvents);
register(FIBAuthor, manifest.authoring.element, observedAttributes, {
    customEvents,
    shadow: true,
    attrs: {
        model: {
            json: true,
        },
    },
    customApi: {
        getSchema: () => schema,
        getUiSchema: () => uiSchema,
        createSchema,
        getAdaptivitySchema: adaptivitySchema,
    },
});
//# sourceMappingURL=authoring-entry.js.map