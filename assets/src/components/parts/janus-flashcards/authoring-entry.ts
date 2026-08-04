import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
  authoringObservedAttributes,
} from '../partsApi';
import FlashcardAuthor from './FlashcardAuthor';
import { adaptivitySchema, createSchema, getCapabilities, schema, uiSchema } from './schema';

/* eslint-disable @typescript-eslint/no-var-requires */
const manifest = require('./manifest.json');

const observedAttributes: string[] = [
  ...apiObservedAttributes,
  ...authoringObservedAttributes,
  'layoutchanging',
];
const customEvents: any = {
  ...apiCustomEvents,
  onConfigure: 'configure',
  onSaveConfigure: 'saveconfigure',
  onCancelConfigure: 'cancelconfigure',
};

register(FlashcardAuthor, manifest.authoring.element, observedAttributes, {
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
    getCapabilities,
    createSchema,
    getAdaptivitySchema: adaptivitySchema,
  },
});
