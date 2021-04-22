import guid from 'utils/guid';
import { ShortAnswerModelSchema } from './schema';
import { ScoringStrategy } from '../types';
import { fromText } from '../common/utils';

export const makeResponse = (rule: string, score: number, text: '') =>
  ({ id: guid(), rule, score, feedback: fromText(text) });


export const parseInputFromRule = (rule: string) => {
  return rule.substring(rule.indexOf('{') + 1, rule.indexOf('}'));
};

export const defaultModel: () => ShortAnswerModelSchema = () => {

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
      previewText: '',
    },
  };
};


export const feedback = (text: string, match: string | number, score = 0) => ({
  ...fromText(text),
  match,
  score,
});
