import guid from 'utils/guid';
import * as ContentModel from 'data/content/model';
import { Choice, MultipleChoiceModelSchema } from './schema';
import { RichText, Operation, ScoringStrategy, EvaluationStrategy } from '../types';

export const makeResponse = (rule: string, score: number, text: '') =>
  ({ id: guid(), rule, score, feedback: fromText(text) });

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
        id: '1', // an MCQ only has one part, so it is safe to hardcode the id
        scoringStrategy: ScoringStrategy.average,
        responses: [
          makeResponse(`input like {${choiceA.id}}`, 1, ''),
          makeResponse(`input like {${choiceB.id}}`, 0, ''),
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
