import guid from 'utils/guid';
import * as ContentModel from 'data/content/model';
import { Choice, MultipleChoiceModelSchema } from './schema';
import { RichText, Operation, ScoringStrategy, EvaluationStrategy } from '../types';

export const makeResponse = (match: string, score: number, text: '') =>
  ({ id: guid(), match, score, feedback: fromText(text) });

export const defaultMCModel : () => MultipleChoiceModelSchema = () => {
  const choiceA: Choice = fromText('Choice A');
  const choiceB: Choice = fromText('Choice B');

  return {
    stem: fromText(''),
    choices: [
      choiceA,
      choiceB,
    ],
    authoring: {
      parts: [{
        id: guid(),
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
      transformations: [
        { id: guid(), path: 'choices', operation: Operation.shuffle },
      ],
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
