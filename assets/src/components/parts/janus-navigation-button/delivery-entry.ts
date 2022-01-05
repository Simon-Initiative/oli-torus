// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');
import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
} from '../partsApi';
import NavigationButton from './NavigationButton';
import { adaptivitySchema } from './schema';

const observedAttributes: string[] = [...apiObservedAttributes];
const customEvents: any = { ...apiCustomEvents };

register(NavigationButton, manifest.delivery.element, observedAttributes, {
  customEvents,
  shadow: false,
  customApi: {
    getAdaptivitySchema: async () => adaptivitySchema,
  },
});
