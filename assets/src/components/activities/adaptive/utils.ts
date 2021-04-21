import guid from 'utils/guid';
import * as ContentModel from 'data/content/model';
import { AdaptiveModelSchema } from './schema';
import { RichText, Operation, ScoringStrategy } from '../types';


export const defaultModel: () => AdaptiveModelSchema = () => {

  return {
    content: {},
    authoring: {
      parts: [{
        id: '1', // One part for now
        scoringStrategy: ScoringStrategy.average,
        responses: [],
        outcomes: [{
          id: 'outcome1',
          rule: [],
          actions: [
            { id: 'action1', type: 'StateUpdateActionDesc', update: {} },
          ],
        }],
        hints: [
          fromText(''),
          fromText(''),
          fromText(''),
        ],
      }],
      transformations: [],
      previewText: '',
    },
  };
};

export function fromText(text: string): { id: string, content: RichText } {
  return {
    id: guid() + '',
    content: {
      model: [
        ContentModel.create<ContentModel.Paragraph>({
          type: 'p',
          children: [{ text }],
          id: guid() + '',
        }),
      ],
      selection: null,
    },
  };
}

export const feedback = (text: string, match: string | number, score = 0) => ({
  ...fromText(text),
  match,
  score,
});
