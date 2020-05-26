import guid from 'utils/guid';
import * as ContentModel from 'data/content/model';
import { ShortAnswerModelSchema } from './schema';
import { RichText, Operation, ScoringStrategy, EvaluationStrategy } from '../types';

export const makeResponse = (match: string, score: number, text: '') =>
  ({ id: guid(), match, score, feedback: fromText(text) });

export const defaultModel : () => ShortAnswerModelSchema = () => {

  return {
    stem: fromText(''),
    authoring: {
      parts: [{
        id: '1', // an short answer only has one part, so it is safe to hardcode the id
        scoringStrategy: ScoringStrategy.average,
        evaluationStrategy: EvaluationStrategy.regex,
        responses: [
          makeResponse(choiceA.id, 1, ''),
          makeResponse(choiceB.id, 0, ''),
        ],
        hints: [
          fromText(''),
          fromText(''),
          fromText(''),
        ],
      }],
      transformations: [],
    },
  };
};

export function fromText(text: string): { id: string, content: RichText } {
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

export const feedback = (text: string, match: string | number, score: number = 0) => ({
  ...fromText(text),
  match,
  score,
});
