import { ShortAnswerModelSchema } from './schema';
import { HasParts, makeHint, makeResponse, makeStem, ScoringStrategy } from '../types';
import { containsRule, matchRule } from 'components/activities/common/responses/authoring/rules';
import {
  getCorrectResponse,
  getIncorrectResponse,
  getResponses,
} from 'components/activities/common/responses/authoring/responseUtils';

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
            makeResponse(containsRule('answer'), 1, ''),
            makeResponse(matchRule('.*'), 0, ''),
          ],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      transformations: [],
      previewText: '',
    },
  };
};

export const getTargetedResponses = (model: HasParts) =>
  getResponses(model).filter(
    (response) =>
      response !== getCorrectResponse(model) && response !== getIncorrectResponse(model),
  );
