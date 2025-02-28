import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
} from '../partsApi';
import HubSpoke from './HubSpoke';
import { adaptivitySchema } from './schema';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');

const observedAttributes: string[] = [...apiObservedAttributes];
const customEvents: any = { ...apiCustomEvents };

register(HubSpoke, manifest.delivery.element, observedAttributes, {
  customEvents,
  shadow: false,
  customApi: {
    getAdaptivitySchema: async () => adaptivitySchema,
  },
});
