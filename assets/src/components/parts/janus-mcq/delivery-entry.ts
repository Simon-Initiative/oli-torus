// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json');
import register from '../customElementWrapper';
import {
  customEvents as apiCustomEvents,
  observedAttributes as apiObservedAttributes,
} from '../partsApi';
import MultipleChoiceQuestion from './MultipleChoiceQuestion';
import { adaptivitySchema } from './schema';

const observedAttributes: string[] = [...apiObservedAttributes];
const customEvents: any = { ...apiCustomEvents };

register(MultipleChoiceQuestion, manifest.delivery.element, observedAttributes, {
  customEvents,
  shadow: false,
  customApi: {
    getAdaptivitySchema: async () => adaptivitySchema,
  },
});
