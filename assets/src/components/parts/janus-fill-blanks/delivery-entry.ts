// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');
import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
} from '../partsApi';
import FillBlanks from './FillBlanks';
import { adaptivitySchema } from './schema';

const observedAttributes: string[] = [...apiObservedAttributes];
const customEvents: any = { ...apiCustomEvents };

register(FillBlanks, manifest.delivery.element, observedAttributes, {
  customEvents,
  shadow: true,
  attrs: {
    model: {
      json: true,
    },
  },
  customApi: {
    getAdaptivitySchema: adaptivitySchema,
  },
});
