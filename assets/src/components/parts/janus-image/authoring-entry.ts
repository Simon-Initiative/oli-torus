import register from '../customElementWrapper';
import {
  PartAuthoringMode,
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
} from '../partsApi';
import ImageAuthor from './ImageAuthor';
import {
  createSchema,
  getSchema,
  getSimpleSchema,
  transformModelToSchema,
  transformSchemaToModel,
  uiSchema,
} from './schema';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');

const observedAttributes: string[] = [...apiObservedAttributes];
const customEvents: any = { ...apiCustomEvents, onSaveConfigure: 'saveconfigure' };
type SchemaOptions = {
  allowAiTriggers?: boolean;
};

register(ImageAuthor, manifest.authoring.element, observedAttributes, {
  customEvents,
  shadow: false,
  attrs: {
    model: {
      json: true,
    },
  },
  customApi: {
    getSchema: (mode: PartAuthoringMode, options?: SchemaOptions) =>
      mode === 'simple'
        ? getSimpleSchema(options?.allowAiTriggers === true)
        : getSchema(options?.allowAiTriggers === true),
    getUiSchema: () => uiSchema,
    transformModelToSchema,
    transformSchemaToModel,
    createSchema,
  },
});
