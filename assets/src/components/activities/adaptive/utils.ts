import { ScoringStrategy, makeHint } from '../types';
import { AdaptiveModelSchema } from './schema';

export const defaultModel: () => AdaptiveModelSchema = () => {
  return {
    content: {},
    authoring: {
      parts: [
        {
          id: '1',
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
