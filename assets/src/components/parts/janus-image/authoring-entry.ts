// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');
import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
} from '../partsApi';
import Image from './Image';
import {
  createSchema,
  schema,
  transformModelToSchema,
  transformSchemaToModel,
  requiredFields,
  uiSchema,
} from './schema';

const observedAttributes: string[] = [...apiObservedAttributes];
const customEvents: any = { ...apiCustomEvents };

register(Image, manifest.authoring.element, observedAttributes, {
  customEvents,
  shadow: false,
  customApi: {
    getSchema: () => schema,
    getUiSchema: () => uiSchema,
    transformModelToSchema,
    transformSchemaToModel,
    createSchema,
  },
});
