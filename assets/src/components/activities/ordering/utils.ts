import { Responses } from 'data/activities/model/responses';
import { matchInOrderRule } from 'data/activities/model/rules';
import guid from 'utils/guid';
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
} from '../types';
import { OrderingSchema as Ordering } from './schema';

// Model creation
export const defaultOrderingModel = (): Ordering => {
  const choice1 = makeChoice('Choice 1');
  const choice2 = makeChoice('Choice 2');

  const correctResponse = makeResponse(
    matchInOrderRule([choice1.id, choice2.id]),
    1,
    'Correct',
    true,
  );

  return {
    stem: makeStem(''),
    choices: [choice1, choice2],
    authoring: {
      version: 2,
      parts: [
        makePart(
          [correctResponse, Responses.catchAll()],
          [makeHint(''), makeHint(''), makeHint('')],
          '1',
        ),
      ],
      targeted: [],
      correct: [[choice1.id, choice2.id], correctResponse.id],
      transformations: [
        { id: guid(), path: 'choices', operation: Transform.shuffle, firstAttemptOnly: true },
      ],
      previewText: '',
    },
  };
};

export const orderingModel = (creationData: CreationData): Ordering => {
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

  const answers: Choice[] = correctChoices.map((choice) => choices.get(choice) as Choice);
  if (answers.length === 0) {
    throw new Error(`No correct choices provided for ${creationData.title}`);
  }

  const correctFeedback = creationData.correct_feedback ? creationData.correct_feedback : 'Correct';
  const incorrectFeedback = creationData.incorrect_feedback
    ? creationData.incorrect_feedback
    : 'Incorrect';

  const correctResponse = makeResponse(
    matchInOrderRule(answers.map((choice) => choice.id)),
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
      targeted: [],
      correct: [answers.map((choice) => choice.id), correctResponse.id],
      transformations: [
        { id: guid(), path: 'choices', operation: Transform.shuffle, firstAttemptOnly: true },
      ],
      previewText: '',
    },
  };
};
