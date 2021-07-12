import {
  Operation,
  ScoringStrategy,
  Choice,
  makeHint,
  makeChoice,
  makeStem,
  makeResponse,
  makeTransformation,
} from '../types';
import { Maybe } from 'tsmonad';
import { getChoice } from 'components/activities/common/choices/authoring/choiceUtils';
import { matchRule } from 'components/activities/common/responses/authoring/rules';
import { getCorrectResponse } from 'components/activities/common/responses/authoring/responseUtils';
import { MCSchema } from 'components/activities/multiple_choice/schema';

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
          id: '1', // an MCQ only has one part, so it is safe to hardcode the id
          scoringStrategy: ScoringStrategy.average,
          responses: [makeResponse(matchRule(choiceA.id), 1, '')],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      targeted: [],
      transformations: [makeTransformation('choices', Operation.shuffle)],
      previewText: '',
    },
  };
};

export const getCorrectChoice = (model: MCSchema) => {
  const responseIdMatch = Maybe.maybe(getCorrectResponse(model).rule.match(/{(.*)}/)).valueOrThrow(
    new Error('Could not find choice id in correct response'),
  );

  return getChoice(model, responseIdMatch[1]);
};
