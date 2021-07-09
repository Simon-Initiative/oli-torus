import guid from 'utils/guid';
import { OrderingSchema as Ordering } from './schema';
import { Operation, ScoringStrategy, makeStem, makeHint, makeChoice, makeResponse } from '../types';
import { matchRule } from 'components/activities/common/responses/authoring/rules';
import { ID } from 'data/content/model';

export const createRuleForIdsOrdering = (orderedIds: ID[]) =>
  `input like {${orderedIds.join(' ')}}`;

// Model creation
export const defaultOrderingModel = (): Ordering => {
  const choice1 = makeChoice('Choice 1');
  const choice2 = makeChoice('Choice 2');

  const correctResponse = makeResponse(createRuleForIdsOrdering([choice1.id, choice2.id]), 1, '');
  const incorrectResponse = makeResponse(matchRule('.*'), 0, '');

  return {
    stem: makeStem(''),
    choices: [choice1, choice2],
    authoring: {
      version: 2,
      parts: [
        {
          id: '1', // a only has one part, so it is safe to hardcode the id
          scoringStrategy: ScoringStrategy.average,
          responses: [correctResponse, incorrectResponse],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      targeted: [],
      correct: [[choice1.id, choice2.id], correctResponse.id],
      transformations: [{ id: guid(), path: 'choices', operation: Operation.shuffle }],
      previewText: '',
    },
  };
};
