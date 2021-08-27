import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
} from '../partsApi';
import { createSchema, schema, uiSchema } from './schema';
import TextFlowAuthor from './TextFlowAuthor';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');

const observedAttributes: string[] = [...apiObservedAttributes, 'editmode', 'configuremode'];
const customEvents: any = { ...apiCustomEvents };

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
    createSchema,
  },
});
