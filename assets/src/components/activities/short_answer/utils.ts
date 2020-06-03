import guid from 'utils/guid';
import * as ContentModel from 'data/content/model';
import { ShortAnswerModelSchema } from './schema';
import { RichText, Operation, ScoringStrategy, EvaluationStrategy } from '../types';
import { fromText } from '../common/utils';

export const makeResponse = (rule: string, score: number, text: '') =>
  ({ id: guid(), rule, score, feedback: fromText(text) });


export const parseInputFromRule = (rule: string) => {
  return rule.substring(rule.indexOf('{') + 1, rule.indexOf('}'));
};

export const defaultModel : () => ShortAnswerModelSchema = () => {

  return {
    stem: fromText(''),
    inputType: 'text',
    authoring: {
      parts: [{
        id: '1', // an short answer only has one part, so it is safe to hardcode the id
        scoringStrategy: ScoringStrategy.average,
        responses: [
          makeResponse('input like {answer}', 1, ''),
          makeResponse('input like {.*}', 0, ''),
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


export const feedback = (text: string, match: string | number, score: number = 0) => ({
  ...fromText(text),
  match,
  score,
});
