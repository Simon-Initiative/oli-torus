import register from '../customElementWrapper';
import {
  authoringObservedAttributes,
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
  PartAuthoringMode,
} from '../partsApi';
import {
  createSchema,
  getCapabilities,
  schema,
  transformModelToSchema,
  transformSchemaToModel,
  uiSchema,
  adaptivitySchema,
  validateUserConfig,
  simpleSchema,
  simpleUISchema,
} from './schema';
import TextFlowAuthor from './TextFlowAuthor';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');

const observedAttributes: string[] = [...apiObservedAttributes, ...authoringObservedAttributes];
const customEvents: any = {
  ...apiCustomEvents,
  onConfigure: 'configure',
  onSaveConfigure: 'saveconfigure',
  onCancelConfigure: 'cancelconfigure',
};

register(TextFlowAuthor, manifest.authoring.element, observedAttributes, {
  customEvents,
  shadow: true,
  attrs: {
    model: {
      json: true,
    },
  },
  customApi: {
    getSchema: (mode: PartAuthoringMode) => (mode === 'simple' ? simpleSchema : schema),
    getUiSchema: (mode: PartAuthoringMode) => (mode === 'simple' ? simpleUISchema : uiSchema),
    transformModelToSchema,
    transformSchemaToModel,
    createSchema,
    getCapabilities,
    getAdaptivitySchema: async () => adaptivitySchema,
    validateUserConfig,
  },
});
