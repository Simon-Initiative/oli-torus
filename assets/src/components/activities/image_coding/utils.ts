import guid from 'utils/guid';
import * as ContentModel from 'data/content/model';
import { ImageCodingModelSchema } from './schema';
import { RichText, Operation, ScoringStrategy, Choice } from '../types';

export const makeResponse = (rule: string, score: number, text: '') =>
  ({ id: guid(), rule, score, feedback: fromText(text) });

export const defaultICModel : () => ImageCodingModelSchema = () => {

  return {
    stem: fromText(''),
    isExample: false,
    starterCode: 'Sample Starter Code',
    solutionCode: 'Sample Solution Code',
    tolerance: 0.0,
    regex: '',
    authoring: {
      parts: [{
        id: '1', // an IC only has one part, so it is safe to hardcode the id
        scoringStrategy: ScoringStrategy.average,
        responses: [
          makeResponse('input like {answer}', 1, ''),
        ],
        hints: [
          fromText(''),
          fromText(''),
          fromText(''),
        ],
      }],
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

export const feedback = (text: string, match: string | number, score: number = 0) => ({
  ...fromText(text),
  match,
  score,
});
