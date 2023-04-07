/* eslint-disable @typescript-eslint/no-var-requires */
const manifest = require('./manifest.json');
import register from '../customElementWrapper';

import {
  authoringObservedAttributes,
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
  PartAuthoringMode,
} from '../partsApi';
import PopupAuthor from './PopupAuthor';
import {
  adaptivitySchema,
  createSchema,
  getCapabilities,
  schema,
  simpleSchema,
  simpleUISchema,
  transformModelToSchema,
  transformSchemaToModel,
  uiSchema,
} from './schema';

const observedAttributes: string[] = [...apiObservedAttributes, ...authoringObservedAttributes];
const customEvents: any = {
  ...apiCustomEvents,
  onConfigure: 'configure',
  onSaveConfigure: 'saveconfigure',
  onCancelConfigure: 'cancelconfigure',
};

register(PopupAuthor, manifest.authoring.element, observedAttributes, {
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
    getAdaptivitySchema: async () => adaptivitySchema,
    transformModelToSchema,
    transformSchemaToModel,
    createSchema,
    getCapabilities,
  },
});
