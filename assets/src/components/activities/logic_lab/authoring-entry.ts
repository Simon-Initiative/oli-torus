import { registerCreationFunc } from '../creation';
import { CreationContext, GradingApproach, Manifest, ScoringStrategy, makeFeedback, makeHint } from '../types';
import { LogicLabModelSchema } from './LogicLabModelSchema';

export { LogicLabAuthoring } from './LogicLabAuthoring';
export { LogicLabDelivery } from './LogicLabDelivery';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest: Manifest = require('./manifest.json');

const labServer = 'http://localhost:5173/?activity='; // 'http://localhost:8080/api/v1/activity/lab/'

registerCreationFunc(manifest, async (content: CreationContext): Promise<LogicLabModelSchema> => {
  return {
    src: labServer,
    activity: '',
    authoring: {
      version: 1,
      parts: [{
        id: '1',
        gradingApproach: GradingApproach.automatic,
        outOf: null,
        scoringStrategy: ScoringStrategy.best,
        responses: [],
        hints: [makeHint(''), makeHint(''), makeHint('')],
        targets: [],
      }],
      transformations: [],
      previewText: '',
    },
    feedback: [
      makeFeedback('incomplete'),
      makeFeedback('complete'),
    ]
  }
});
