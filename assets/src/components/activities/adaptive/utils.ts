import guid from 'utils/guid';
import * as ContentModel from 'data/content/model';
import { AdaptiveModelSchema } from './schema';
import { RichText, ScoringStrategy } from '../types';
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
          hints: [fromText(''), fromText(''), fromText('')],
        },
      ],
      transformations: [],
      previewText: '',
    },
  };
};

export function fromText(text: string): { id: string; content: RichText } {
  return {
    id: guid() + '',
    content: [
      ContentModel.create<ContentModel.Paragraph>({
        type: 'p',
        children: [{ text }],
        id: guid() + '',
      }),
    ],
  };
}

export const feedback = (text: string, match: string | number, score = 0) => ({
  ...fromText(text),
  match,
  score,
});
