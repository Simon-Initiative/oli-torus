import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
  authoringObservedAttributes,
} from '../partsApi';
import TextFlowAuthor from './TextFlowAuthor';
import {
  adaptivitySchema,
  createSchema,
  getCapabilities,
  schema,
  transformModelToSchema,
  transformSchemaToModel,
  uiSchema,
  validateUserConfig,
} from './schema';

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
    getSchema: () => schema,
    getUiSchema: () => uiSchema,
    transformModelToSchema,
    transformSchemaToModel,
    createSchema,
    getCapabilities,
    getAdaptivitySchema: async () => adaptivitySchema,
    validateUserConfig,
  },
});
