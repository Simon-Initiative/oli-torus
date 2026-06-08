import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
} from '../partsApi';
import Grouping from './Grouping';
import { adaptivitySchema } from './schema';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');

const observedAttributes: string[] = [...apiObservedAttributes];
const customEvents: any = { ...apiCustomEvents };

const registrationOptions = {
  customEvents,
  shadow: false,
  attrs: {
    model: {
      json: true,
    },
  },
  customApi: {
    getAdaptivitySchema: adaptivitySchema,
  },
};

register(Grouping, manifest.delivery.element, observedAttributes, registrationOptions);

// Legacy tag from early development (content may still reference janus-grouping).
if (!customElements.get('janus-grouping')) {
  register(Grouping, 'janus-grouping', observedAttributes, registrationOptions);
}
