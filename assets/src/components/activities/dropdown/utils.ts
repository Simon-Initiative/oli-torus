import { DropdownModelSchema } from './schema';
import {
  HasParts,
  makeHint,
  makeResponse,
  makeStem,
  makeTransformation,
  Operation,
  ScoringStrategy,
} from '../types';
import { containsRule, matchRule } from 'components/activities/common/responses/authoring/rules';
import {
  getCorrectResponse,
  getIncorrectResponse,
  getResponses,
} from 'components/activities/common/responses/authoring/responseUtils';

export const defaultModel: () => DropdownModelSchema = () => {
  return {
    stem: makeStem(''),
    authoring: {
      parts: [
        {
          id: '1',
          scoringStrategy: ScoringStrategy.average,
          responses: [
            makeResponse(containsRule('answer'), 1, ''),
            makeResponse(matchRule('.*'), 0, ''),
          ],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      transformations: [makeTransformation('choices', Operation.shuffle)],
      previewText: '',
    },
  };
};

export const getTargetedResponses = (model: HasParts) =>
  getResponses(model).filter(
    (response) =>
      response !== getCorrectResponse(model) && response !== getIncorrectResponse(model),
  );
