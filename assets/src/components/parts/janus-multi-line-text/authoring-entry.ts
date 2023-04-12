/* eslint-disable @typescript-eslint/no-var-requires */
const manifest = require('./manifest.json');
import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
  PartAuthoringMode,
} from '../partsApi';
import MultiLineTextInputAuthor from './MultiLineTextInputAuthor';
import {
  adaptivitySchema,
  createSchema,
  schema,
  simpleSchema,
  simpleUiSchema,
  uiSchema,
} from './schema';

const observedAttributes: string[] = [...apiObservedAttributes];
const customEvents: any = { ...apiCustomEvents };

register(MultiLineTextInputAuthor, manifest.authoring.element, observedAttributes, {
  customEvents,
  shadow: false,
  attrs: {
    model: {
      json: true,
    },
  },
  customApi: {
    getSchema: (mode: PartAuthoringMode) => (mode === 'simple' ? simpleSchema : schema),
    getUiSchema: (mode: PartAuthoringMode) => (mode === 'simple' ? simpleUiSchema : uiSchema),
    createSchema,
    getAdaptivitySchema: async () => adaptivitySchema,
  },
});
