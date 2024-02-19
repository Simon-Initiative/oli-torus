import { registerCreationFunc } from '../creation';
import { CreationContext, Manifest, makeFeedback, makePart } from '../types';
import { LogicLabModelSchema } from './LogicLabModelSchema';

export { LogicLabDelivery} from './LogicLabDelivery';
export { LogicLabAuthoring} from './LogicLabAuthoring';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest: Manifest = require('./manifest.json');

const labServer = 'http://localhost:5173/?activity='; // 'http://localhost:8080/api/v1/activity/lab/'

registerCreationFunc(manifest, async (content: CreationContext): Promise<LogicLabModelSchema> => {
  return {
    src: labServer,
    authoring: {
      version: 1,
      parts: [makePart([])],
      transformations: [],
      previewText: '',
    },
    feedback: [
      makeFeedback('incomplete'),
      makeFeedback('complete'),
    ]
  }
});
