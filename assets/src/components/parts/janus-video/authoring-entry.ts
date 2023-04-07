/* eslint-disable @typescript-eslint/no-var-requires */
const manifest = require('./manifest.json');
import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
  PartAuthoringMode,
} from '../partsApi';
import {
  adaptivitySchema,
  createSchema,
  schema,
  simpleSchema,
  simpleUISchema,
  uiSchema,
} from './schema';
import VideoAuthor from './VideoAuthor';

const observedAttributes: string[] = [...apiObservedAttributes];
const customEvents: any = { ...apiCustomEvents };

register(VideoAuthor, manifest.authoring.element, observedAttributes, {
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
