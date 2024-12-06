import { Maybe } from 'tsmonad';
import { MCSchema } from 'components/activities/multiple_choice/schema';
import {
  Choice,
  CreationData,
  HasParts,
  Hint,
  Part,
  Transform,
  makeChoice,
  makeFeedback,
  makeHint,
  makePart,
  makeStem,
  makeTransformation,
} from 'components/activities/types';
import { Choices } from 'data/activities/model/choices';
import { Responses, getCorrectResponse } from 'data/activities/model/responses';

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
      transformations: [makeTransformation('choices', Transform.shuffle, true)],
      previewText: '',
    },
  };
};

export const mCModel: (creationData: CreationData) => MCSchema = (creationData: CreationData) => {
  const choices: Map<string, Choice> = new Map();
  Object.entries(creationData)
    .filter(([key, value]) => key.startsWith('choice') && value)
    .map(([key, value]) => {
      const choice = makeChoice(value.toString());
      choices.set(key, choice);
      return choice;
    });

  if (choices.size === 0) {
    throw new Error(`No choices provided for ${creationData.title}`);
  }

  const hints: Hint[] = Object.entries(creationData)
    .filter(([key, _value]) => key.startsWith('hint'))
    .map(([_key, value]) => {
      if (value) {
        return makeHint(value.toString());
      }
      return makeHint('');
    });

  let answer: Choice = choices.get(`choice${creationData.answer}`) as Choice;

  if (!answer) {
    throw new Error('No answer provided');
  }

  const correctFeedback = creationData.correct_feedback ? creationData.correct_feedback : 'Correct';
  const incorrectFeedback = creationData.incorrect_feedback
    ? creationData.incorrect_feedback
    : 'Incorrect';

  const part: Part = makePart(
    Responses.forMultipleChoice(answer.id, correctFeedback, incorrectFeedback),
    hints,
    '1',
  );

  if (creationData.explanation) {
    part.explanation = makeFeedback(creationData.explanation);
  }

  const stem = creationData.stem ? creationData.stem : '';

  return {
    stem: makeStem(stem),
    choices: [...choices.values()],
    authoring: {
      version: 2,
      parts: [part],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle, true)],
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

  return Maybe.just(choice);
};
