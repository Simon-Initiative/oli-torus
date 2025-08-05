import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
} from '../partsApi';
import Formula from './Formula';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');

const observedAttributes: string[] = [...apiObservedAttributes];
const customEvents: any = { ...apiCustomEvents };

register(Formula, manifest.delivery.element, observedAttributes, {
  customEvents,
  shadow: false,
  attrs: {
    model: {
      json: true,
    },
  },
});
