import { AdaptiveModelSchema } from './schema';
import { ScoringStrategy, makeHint } from '../types';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';

export const defaultModel: () => AdaptiveModelSchema = () => {
  return {
    content: {},
    authoring: {
      parts: [
        {
          id: DEFAULT_PART_ID,
          scoringStrategy: ScoringStrategy.average,
          responses: [],
          outcomes: [
            {
              id: 'outcome1',
              rule: [],
              actions: [{ id: 'action1', type: 'StateUpdateActionDesc', update: {} }],
            },
          ],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      transformations: [],
      previewText: '',
    },
  };
};
