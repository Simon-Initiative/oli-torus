import {
  makeChoice,
  makeHint,
  makeResponse,
  makeStem,
  makeTransformation,
  Transform,
  ScoringStrategy,
} from 'components/activities/types';
import { matchListRule, matchRule } from 'data/activities/model/rules';
import { CATASchema as CATA } from 'components/activities/check_all_that_apply/schema';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';

// Model creation
export const defaultCATAModel = (): CATA => {
  const correctChoice = makeChoice('Choice 1');
  const incorrectChoice = makeChoice('Choice 2');

  const correctResponse = makeResponse(
    matchListRule([correctChoice.id, incorrectChoice.id], [correctChoice.id]),
    1,
    '',
  );
  const incorrectResponse = makeResponse(matchRule('.*'), 0, '');

  return {
    stem: makeStem(''),
    choices: [correctChoice, incorrectChoice],
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
      correct: [[correctChoice.id], correctResponse.id],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle)],
      previewText: '',
    },
  };
};
