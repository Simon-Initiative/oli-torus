import { CATASchema as CATA } from 'components/activities/check_all_that_apply/schema';
import {
  Choice,
  CreationData,
  Hint,
  Part,
  Transform,
  makeChoice,
  makeFeedback,
  makeHint,
  makePart,
  makeResponse,
  makeStem,
  makeTransformation,
} from 'components/activities/types';
import { Responses } from 'data/activities/model/responses';
import { matchListRule } from 'data/activities/model/rules';

export const defaultCATAModel = (): CATA => {
  const correctChoice = makeChoice('Choice 1');
  const incorrectChoice = makeChoice('Choice 2');

  const correctResponse = makeResponse(
    matchListRule([correctChoice.id, incorrectChoice.id], [correctChoice.id]),
    1,
    'Correct',
    true,
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
          '1',
        ),
      ],
      correct: [[correctChoice.id], correctResponse.id],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle, true)],
      previewText: '',
    },
  };
};

export const cATAModel = (creationData: CreationData): CATA => {
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

  const correctChoices: string[] = creationData.answer
    .split(',')
    .map((choice) => `choice${choice}`);

  if (correctChoices.length === 0) {
    throw new Error(`No correct choices provided for ${creationData.title}`);
  }

  const answers: Choice[] = [choices.get('choiceA') as Choice];
  choices.forEach((value: Choice, key: string) => {
    if (correctChoices.includes(key)) {
      answers.push(value);
    }
  });

  if (answers.length === 0) {
    throw new Error(`No correct choices found for ${creationData.title}`);
  }

  const correctFeedback = creationData.correct_feedback ? creationData.correct_feedback : 'Correct';
  const incorrectFeedback = creationData.incorrect_feedback
    ? creationData.incorrect_feedback
    : 'Incorrect';

  const correctResponse = makeResponse(
    matchListRule(
      [...choices.values()].map((choice: Choice) => choice.id),
      answers.map((choice) => choice.id),
    ),
    1,
    correctFeedback,
    true,
  );

  const part: Part = makePart([correctResponse, Responses.catchAll(incorrectFeedback)], hints, '1');

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
      correct: [answers.map((choice) => choice.id), correctResponse.id],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle, true)],
      previewText: '',
    },
  };
};
