/*
  Registers the LogicLab authoring component for use in Torus.
*/
import { registerCreationFunc } from '../creation';
import {
  CreationContext,
  GradingApproach,
  Manifest,
  ScoringStrategy,
  makeFeedback,
  makeHint,
} from '../types';
import { LogicLabModelSchema } from './LogicLabModelSchema';

export { LogicLabAuthoring } from './LogicLabAuthoring';
export { LogicLabDelivery } from './LogicLabDelivery';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest: Manifest = require('./manifest.json');

registerCreationFunc(manifest, async (context: CreationContext): Promise<LogicLabModelSchema> => {
  return {
    activity: '',
    context: { title: context.title },
    authoring: {
      version: 1,
      parts: [
        {
          id: '1',
          gradingApproach: GradingApproach.automatic,
          outOf: null,
          scoringStrategy: ScoringStrategy.best,
          responses: [],
          hints: [makeHint(''), makeHint(''), makeHint('')],
          targets: [],
        },
      ],
      transformations: [],
      previewText: '',
    },
    feedback: [makeFeedback('incomplete'), makeFeedback('complete')],
  };
});
