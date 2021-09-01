import {
  Choice,
  HasParts,
  makeChoice,
  makeHint,
  makeResponse,
  makeStem,
  makeTransformation,
  Transform,
  ScoringStrategy,
} from 'components/activities/types';
import { Maybe } from 'tsmonad';
import { matchRule } from 'data/activities/model/rules';
import { getCorrectResponse } from 'data/activities/model/responseUtils';
import { MCSchema } from 'components/activities/multiple_choice/schema';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { CHOICES_PATH, getChoice } from 'data/activities/model/choiceUtils';

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
      transformations: [makeTransformation('choices', Transform.shuffle)],
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
