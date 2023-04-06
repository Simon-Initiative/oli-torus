/* eslint-disable @typescript-eslint/no-var-requires */
const manifest = require('./manifest.json');
import register from '../customElementWrapper';
import {
  PartAuthoringMode,
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
} from '../partsApi';
import AudioAuthor from './AudioAuthor';
import {
  adaptivitySchema,
  createSchema,
  schema,
  simpleSchema,
  simpleUISchema,
  uiSchema,
} from './schema';

const observedAttributes: string[] = [...apiObservedAttributes];
const customEvents: any = { ...apiCustomEvents };

register(AudioAuthor, manifest.authoring.element, observedAttributes, {
  customEvents,
  shadow: false,
  attrs: {
    model: {
      json: true,
    },
  },
  customApi: {
    getSchema: (mode: PartAuthoringMode) => (mode === 'simple' ? simpleSchema : schema),
    getUiSchema: (mode: PartAuthoringMode) => (mode === 'simple' ? simpleUISchema : uiSchema),
    createSchema,
    getAdaptivitySchema: async () => adaptivitySchema,
  },
});
