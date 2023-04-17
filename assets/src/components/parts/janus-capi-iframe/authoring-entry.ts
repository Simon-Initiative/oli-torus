import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
  authoringObservedAttributes,
} from '../partsApi';
import CapiIframeAuthor from './CapiIframeAuthor';
import {
  adaptivitySchema,
  createSchema,
  getCapabilities,
  schema,
  uiSchema,
  validateUserConfig,
} from './schema';

/* eslint-disable @typescript-eslint/no-var-requires */
const manifest = require('./manifest.json');

const observedAttributes: string[] = [...apiObservedAttributes, ...authoringObservedAttributes];
const customEvents: any = {
  ...apiCustomEvents,
  onConfigure: 'configure',
  onSaveConfigure: 'saveconfigure',
  onCancelConfigure: 'cancelconfigure',
};

register(CapiIframeAuthor, manifest.authoring.element, observedAttributes, {
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
    createSchema,
    getCapabilities,
    getAdaptivitySchema: adaptivitySchema,
    validateUserConfig,
  },
});
