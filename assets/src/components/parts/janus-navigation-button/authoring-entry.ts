import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
} from '../partsApi';
import NavButtonAuthor from './NavButtonAuthor';
import { adaptivitySchema, createSchema, getSchema, uiSchema } from './schema';

/* eslint-disable @typescript-eslint/no-var-requires */
const manifest = require('./manifest.json');

const observedAttributes: string[] = [...apiObservedAttributes];
const customEvents: any = { ...apiCustomEvents };
type SchemaOptions = {
  allowAiTriggers?: boolean;
};

register(NavButtonAuthor, manifest.authoring.element, observedAttributes, {
  customEvents,
  shadow: false,
  attrs: {
    model: {
      json: true,
    },
  },
  customApi: {
    getSchema: (_mode?: unknown, options?: SchemaOptions) =>
      getSchema(options?.allowAiTriggers === true),
    getUiSchema: () => uiSchema,
    createSchema,
    getAdaptivitySchema: async () => adaptivitySchema,
  },
});
