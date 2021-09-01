import { DEFAULT_PART_ID } from './../common/utils';
import guid from 'utils/guid';
import { OrderingSchema as Ordering } from './schema';
import { Transform, ScoringStrategy, makeStem, makeHint, makeChoice, makeResponse } from '../types';
import { matchInOrderRule, matchRule } from 'data/activities/model/rules';

// Model creation
export const defaultOrderingModel = (): Ordering => {
  const choice1 = makeChoice('Choice 1');
  const choice2 = makeChoice('Choice 2');

  const correctResponse = makeResponse(matchInOrderRule([choice1.id, choice2.id]), 1, '');
  const incorrectResponse = makeResponse(matchRule('.*'), 0, '');

  return {
    stem: makeStem(''),
    choices: [choice1, choice2],
    authoring: {
      version: 2,
      parts: [
        {
          id: DEFAULT_PART_ID,
          scoringStrategy: ScoringStrategy.average,
          responses: [correctResponse, incorrectResponse],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      targeted: [],
      correct: [[choice1.id, choice2.id], correctResponse.id],
      transformations: [{ id: guid(), path: 'choices', operation: Transform.shuffle }],
      previewText: '',
    },
  };
};
