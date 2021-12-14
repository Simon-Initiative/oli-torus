import register from '../customElementWrapper';
import { authoringObservedAttributes, customEvents as apiCustomEvents, observedAttributes as apiObservedAttributes, } from '../partsApi';
import { createSchema, getCapabilities, schema, transformModelToSchema, transformSchemaToModel, uiSchema, } from './schema';
import TextFlowAuthor from './TextFlowAuthor';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');
const observedAttributes = [...apiObservedAttributes, ...authoringObservedAttributes];
const customEvents = Object.assign(Object.assign({}, apiCustomEvents), { onConfigure: 'configure', onSaveConfigure: 'saveconfigure', onCancelConfigure: 'cancelconfigure' });
register(TextFlowAuthor, manifest.authoring.element, observedAttributes, {
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
        transformModelToSchema,
        transformSchemaToModel,
        createSchema,
        getCapabilities,
    },
});
//# sourceMappingURL=authoring-entry.js.map