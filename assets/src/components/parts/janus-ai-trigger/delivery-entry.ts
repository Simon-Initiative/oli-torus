import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
} from '../partsApi';
import AITrigger from './AITrigger';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');

const observedAttributes: string[] = [...apiObservedAttributes, 'sectionslug', 'resourceid'];
const customEvents: any = { ...apiCustomEvents };

register(AITrigger, manifest.delivery.element, observedAttributes, {
  customEvents,
  shadow: false,
});
