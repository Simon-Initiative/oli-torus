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
  const correct = getCorrectResponse(model, partId);

  if (correct === null) {
    return Maybe.nothing<Choice>();
  }

  let value = correct.rule.substring(correct.rule.indexOf('{') + 1);
  value = value.substring(0, value.indexOf('}'));

  const choice = Choices.getOne(model, value);
  if (choice === null || choice === undefined) {
    return Maybe.nothing<Choice>();
  }

  console.log(choice);

  return Maybe.just(choice);
};
