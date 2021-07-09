import {
  makeChoice,
  makeHint,
  makeResponse,
  makeStem,
  makeTransformation,
  Operation,
  ScoringStrategy,
} from 'components/activities/types';
import {
  andRules,
  invertRule,
  matchRule,
} from 'components/activities/common/responses/authoring/rules';
import { CATASchema as CATA } from 'components/activities/check_all_that_apply/schema';
import { getCorrectChoiceIds } from 'components/activities/common/responses/authoring/responseUtils';
import { ID } from 'data/content/model';
import { setDifference } from 'components/activities/common/utils';

export const incorrectChoiceIds = (model: CATA) =>
  model.choices.map((c) => c.id).filter((id) => !getCorrectChoiceIds(model).includes(id));

// Model creation
export const defaultCATAModel = (): CATA => {
  const correctChoice = makeChoice('Choice 1');
  const incorrectChoice = makeChoice('Choice 2');

  const correctResponse = makeResponse(
    createRuleForIdsCATA([correctChoice.id, incorrectChoice.id], [correctChoice.id]),
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
          id: '1', // a only has one part, so it is safe to hardcode the id
          scoringStrategy: ScoringStrategy.average,
          responses: [correctResponse, incorrectResponse],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      correct: [[correctChoice.id], correctResponse.id],
      targeted: [],
      transformations: [makeTransformation('choices', Operation.shuffle)],
      previewText: '',
    },
  };
};

export const createRuleForIdsCATA = (allChoiceIds: ID[], toMatch: ID[]) => {
  const notToMatch = setDifference(allChoiceIds, toMatch);
  console.log('not to match', notToMatch);
  return andRules(
    ...toMatch.map(matchRule).concat(notToMatch.map((id) => invertRule(matchRule(id)))),
  );
};
