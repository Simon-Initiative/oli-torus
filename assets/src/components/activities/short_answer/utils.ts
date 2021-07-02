import { InputType, ShortAnswerModelSchema } from './schema';
import { makeHint, makeResponse, makeStem, ScoringStrategy } from '../types';
import {
  parseNumericInputFromRule,
  parseTextInputFromRule,
} from 'components/activities/common/responses/authoring/rules';

export const parseInputFromRule = (rule: string, inputType: InputType) => {
  switch (inputType) {
    case 'numeric':
      return parseNumericInputFromRule(rule);
    case 'text':
      return parseTextInputFromRule(rule);
    case 'textarea':
      return parseTextInputFromRule(rule);
  }
};

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
