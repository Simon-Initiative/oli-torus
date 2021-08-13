import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
} from '../partsApi';
import { schema, uiSchema, createSchema, requiredFields } from './schema';
import TextFlow from './TextFlow';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');

const observedAttributes: string[] = [...apiObservedAttributes];
const customEvents: any = { ...apiCustomEvents };

register(TextFlow, manifest.authoring.element, observedAttributes, {
  customEvents,
  shadow: false,
  customApi: {
    getSchema: () => schema,
    getUiSchema: () => uiSchema,
    getRequiredFields: () => requiredFields,
    createSchema,
  },
});
