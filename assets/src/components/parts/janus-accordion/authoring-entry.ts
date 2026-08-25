import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
  authoringObservedAttributes,
} from '../partsApi';
import AccordionAuthor from './AccordionAuthor';
import { adaptivitySchema, createSchema, schema, uiSchema } from './schema';

/* eslint-disable @typescript-eslint/no-var-requires */
const manifest = require('./manifest.json');

const observedAttributes: string[] = [...apiObservedAttributes, ...authoringObservedAttributes];
const customEvents: any = {
  ...apiCustomEvents,
};

register(AccordionAuthor, manifest.authoring.element, observedAttributes, {
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
    getAdaptivitySchema: () => adaptivitySchema,
  },
});
