import guid from 'utils/guid';
import { MultipleChoiceModelSchema } from './schema';
import {
  Operation,
  ScoringStrategy,
  Choice,
  makeHint,
  makeChoice,
  makeStem,
  makeResponse,
  ChoiceId,
} from '../types';
import { Maybe } from 'tsmonad';
import { getChoice } from 'components/activities/common/choices/authoring/choiceUtils';
import { matchRule } from 'components/activities/common/responses/authoring/rules';
import {
  getCorrectResponse,
  getResponses,
} from 'components/activities/common/responses/authoring/responseUtils';

export const defaultMCModel: () => MultipleChoiceModelSchema = () => {
  const choiceA: Choice = makeChoice('Choice A');
  const choiceB: Choice = makeChoice('Choice B');

  return {
    stem: makeStem(''),
    choices: [choiceA, choiceB],
    authoring: {
      parts: [
        {
          id: '1', // an MCQ only has one part, so it is safe to hardcode the id
          scoringStrategy: ScoringStrategy.average,
          responses: [
            makeResponse(`input like {${choiceA.id}}`, 1, ''),
            makeResponse(`input like {${choiceB.id}}`, 0, ''),
          ],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      transformations: [{ id: guid(), path: 'choices', operation: Operation.shuffle }],
      previewText: '',
    },
  };
};

export const getCorrectChoice = (model: MultipleChoiceModelSchema) => {
  const responseIdMatch = Maybe.maybe(getCorrectResponse(model).rule.match(/{(.*)}/)).valueOrThrow(
    new Error('Could not find choice id in correct response'),
  );

  return getChoice(model, responseIdMatch[1]);
};

export const getResponseByChoice = (model: MultipleChoiceModelSchema, id: ChoiceId) => {
  return getResponses(model).filter((r) => r.rule === matchRule(id))[0];
};
