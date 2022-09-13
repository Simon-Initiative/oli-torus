import { MCSchema } from 'components/activities/multiple_choice/schema';
import {
  Choice,
  HasParts,
  makeChoice,
  makeHint,
  makePart,
  makeStem,
  makeTransformation,
  Transform,
} from 'components/activities/types';
import { Choices } from 'data/activities/model/choices';
import { getCorrectResponse, Responses } from 'data/activities/model/responses';
import { Maybe } from 'tsmonad';

export const defaultMCModel: () => MCSchema = () => {
  const choiceA: Choice = makeChoice('Choice A');
  const choiceB: Choice = makeChoice('Choice B');

  return {
    stem: makeStem(''),
    choices: [choiceA, choiceB],
    authoring: {
      version: 2,
      parts: [
        makePart(
          Responses.forMultipleChoice(choiceA.id),
          [makeHint(''), makeHint(''), makeHint('')],
          '1',
        ),
      ],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle)],
      previewText: '',
    },
  };
};

export const getCorrectChoice = (model: HasParts, partId: string) => {
  const responseIdMatch = Maybe.maybe(
    getCorrectResponse(model, partId).rule.match(/{(.*)}/),
  ).valueOrThrow(new Error('Could not find choice id in correct response'));

  return Choices.getOne(model, responseIdMatch[1]);
};
