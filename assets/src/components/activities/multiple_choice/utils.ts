import {
  Choice,
  HasParts,
  makeChoice,
  makeHint,
  makeResponse,
  makeStem,
  makeTransformation,
  Operation,
  ScoringStrategy,
} from 'components/activities/types';
import { Maybe } from 'tsmonad';
import {
  CHOICES_PATH,
  getChoice,
} from 'components/activities/common/choices/authoring/choiceUtils';
import { matchRule } from 'components/activities/common/responses/authoring/rules';
import { getCorrectResponse } from 'components/activities/common/responses/authoring/responseUtils';
import { MCSchema } from 'components/activities/multiple_choice/schema';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';

export const defaultMCModel: () => MCSchema = () => {
  const choiceA: Choice = makeChoice('Choice A');
  const choiceB: Choice = makeChoice('Choice B');

  return {
    stem: makeStem(''),
    choices: [choiceA, choiceB],
    authoring: {
      version: 2,
      parts: [
        {
          id: DEFAULT_PART_ID, // an MCQ only has one part, so it is safe to hardcode the id
          scoringStrategy: ScoringStrategy.average,
          responses: [
            makeResponse(matchRule(choiceA.id), 1, ''),
            makeResponse(matchRule('.*'), 0, ''),
          ],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      targeted: [],
      transformations: [makeTransformation('choices', Operation.shuffle)],
      previewText: '',
    },
  };
};

export const getCorrectChoice = (
  model: HasParts,
  partId = DEFAULT_PART_ID,
  choicesPath = CHOICES_PATH,
) => {
  const responseIdMatch = Maybe.maybe(
    getCorrectResponse(model, partId).rule.match(/{(.*)}/),
  ).valueOrThrow(new Error('Could not find choice id in correct response'));

  return getChoice(model, responseIdMatch[1], choicesPath);
};
