import { ShortAnswerModelSchema } from './schema';
import { makeHint, makeResponse, makeStem, ScoringStrategy } from '../types';

export const parseInputFromRule = (rule: string) => {
  return rule.substring(rule.indexOf('{') + 1, rule.indexOf('}'));
};

export const parseOperatorFromRule = (rule: string): operator => {
  switch (true) {
    case rule.includes('>') && rule.includes('='):
      return 'gte';
    case rule.includes('>'):
      return 'gt';
    case rule.includes('<') && rule.includes('='):
      return 'lte';
    case rule.includes('<'):
      return 'lt';
    case rule.includes('='):
      return 'eq';
    default:
      throw new Error('Operator could not be found in rule ' + rule);
  }
};
export type operator = 'gt' | 'gte' | 'eq' | 'lt' | 'lte';
export function isOperator(s: string): s is operator {
  return ['gt', 'gte', 'eq', 'lt', 'lte'].includes(s);
}

export const isCatchAllRule = (input: string) => input === '.*';

export const defaultModel: () => ShortAnswerModelSchema = () => {
  return {
    stem: makeStem(''),
    inputType: 'text',
    authoring: {
      parts: [
        {
          id: '1', // an short answer only has one part, so it is safe to hardcode the id
          scoringStrategy: ScoringStrategy.average,
          responses: [
            makeResponse('input like {answer}', 1, ''),
            makeResponse('input like {.*}', 0, ''),
          ],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      transformations: [],
      previewText: '',
    },
  };
};
