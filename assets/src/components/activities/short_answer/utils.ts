import { ShortAnswerModelSchema } from './schema';
import { makeHint, makeResponse, makeStem, ScoringStrategy } from '../types';
import {
  containsRule,
  matchRule,
  parseInputFromRule,
} from 'components/activities/common/responses/authoring/rules';
import {
  getCorrectResponse,
  getResponses,
} from 'components/activities/common/responses/authoring/responseUtils';
import { Maybe } from 'tsmonad';

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

export const getTargetedResponses = (model: ShortAnswerModelSchema) =>
  getResponses(model).filter(
    (response) =>
      response !== getCorrectResponse(model) && response !== getIncorrectResponse(model),
  );

export const getIncorrectResponse = (model: ShortAnswerModelSchema) =>
  Maybe.maybe(
    getResponses(model).find((response) => parseInputFromRule(response.rule) === '.*'),
  ).valueOrThrow(new Error('Could not find incorrect response for short answer'));
