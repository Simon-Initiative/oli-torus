import { CATASchema as CATA } from 'components/activities/check_all_that_apply/schema';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
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
    '',
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
          DEFAULT_PART_ID,
        ),
      ],
      correct: [[correctChoice.id], correctResponse.id],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle)],
      previewText: '',
    },
  };
};
