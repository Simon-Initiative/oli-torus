import { CATASchema as CATA } from 'components/activities/check_all_that_apply/schema';
import {
  makeChoice,
  makeHint,
  makePart,
  makeResponse,
  makeStem,
  makeTransformation,
  Transform,
} from 'components/activities/types';
import { Responses } from 'data/activities/model/responses';
import { matchListRule } from 'data/activities/model/rules';

export const defaultCATAModel = (): CATA => {
  const correctChoice = makeChoice('Choice 1');
  const incorrectChoice = makeChoice('Choice 2');

  const correctResponse = makeResponse(
    matchListRule([correctChoice.id, incorrectChoice.id], [correctChoice.id]),
    1,
    'Correct',
  );

  return {
    stem: makeStem(''),
    choices: [correctChoice, incorrectChoice],
    authoring: {
      version: 2,
      parts: [
        makePart(
          [correctResponse, Responses.catchAll()],
          [makeHint(''), makeHint(''), makeHint('')],
          '1',
        ),
      ],
      correct: [[correctChoice.id], correctResponse.id],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle, true)],
      previewText: '',
    },
  };
};
