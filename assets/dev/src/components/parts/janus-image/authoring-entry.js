// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');
import register from '../customElementWrapper';
import { customEvents as apiCustomEvents, observedAttributes as apiObservedAttributes, } from '../partsApi';
import ImageAuthor from './ImageAuthor';
import { createSchema, schema, transformModelToSchema, transformSchemaToModel, uiSchema, } from './schema';
const observedAttributes = [...apiObservedAttributes];
const customEvents = Object.assign({}, apiCustomEvents);
register(ImageAuthor, manifest.authoring.element, observedAttributes, {
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
        transformModelToSchema,
        transformSchemaToModel,
        createSchema,
    },
});
//# sourceMappingURL=authoring-entry.js.map