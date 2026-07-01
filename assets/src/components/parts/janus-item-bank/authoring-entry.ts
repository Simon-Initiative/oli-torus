import register from '../customElementWrapper';
import {
  PartAuthoringMode,
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
} from '../partsApi';
import GroupingAuthor from './GroupingAuthor';
import {
  adaptivitySchema,
  createSchema,
  getCapabilities,
  schema,
  simpleSchema,
  simpleUiSchema,
  uiSchema,
} from './schema';

/* eslint-disable @typescript-eslint/no-var-requires */
const manifest = require('./manifest.json');

const observedAttributes: string[] = [...apiObservedAttributes];

const registrationOptions = {
  customEvents: apiCustomEvents,
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
    getCapabilities,
    getAdaptivitySchema: adaptivitySchema,
  },
};

register(GroupingAuthor, manifest.authoring.element, observedAttributes, registrationOptions);

// Legacy tag from early development (content may still reference janus-grouping).
if (!customElements.get('janus-grouping')) {
  register(GroupingAuthor, 'janus-grouping', observedAttributes, registrationOptions);
}
