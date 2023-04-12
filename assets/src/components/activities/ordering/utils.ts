import { Transform, makeChoice, makeHint, makePart, makeResponse, makeStem } from '../types';
import { OrderingSchema as Ordering } from './schema';
import { Responses } from 'data/activities/model/responses';
import { matchInOrderRule } from 'data/activities/model/rules';
import guid from 'utils/guid';

// Model creation
export const defaultOrderingModel = (): Ordering => {
  const choice1 = makeChoice('Choice 1');
  const choice2 = makeChoice('Choice 2');

  const correctResponse = makeResponse(matchInOrderRule([choice1.id, choice2.id]), 1, 'Correct');

  return {
    stem: makeStem(''),
    choices: [choice1, choice2],
    authoring: {
      version: 2,
      parts: [
        makePart(
          [correctResponse, Responses.catchAll()],
          [makeHint(''), makeHint(''), makeHint('')],
          '1',
        ),
      ],
      targeted: [],
      correct: [[choice1.id, choice2.id], correctResponse.id],
      transformations: [
        { id: guid(), path: 'choices', operation: Transform.shuffle, firstAttemptOnly: true },
      ],
      previewText: '',
    },
  };
};
