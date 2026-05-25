import { Choice, ChoiceId, HasParts, Part, Response } from 'components/activities/types';
import {
  findTargetedResponses,
  getCorrectChoiceIds,
  getCorrectResponse,
  getIncorrectResponse,
} from 'data/activities/model/responses';

export const firstPart = (model: HasParts): Part => model.authoring.parts[0];

export const choiceMapById = (choices: Choice[]): Record<string, Choice> =>
  choices.reduce<Record<string, Choice>>((acc, choice) => {
    acc[choice.id] = choice;
    return acc;
  }, {});

export const selectedChoices = (choices: Choice[], choiceIds: ChoiceId[]): Choice[] => {
  const selectedIds = new Set(choiceIds);
  return choices.filter((choice) => selectedIds.has(choice.id));
};

export const choicesInIdOrder = (choices: Choice[], choiceIds: ChoiceId[]): Choice[] => {
  const choicesById = choiceMapById(choices);
  return choiceIds
    .map((choiceId) => choicesById[choiceId])
    .filter((choice): choice is Choice => Boolean(choice));
};

export const standardFeedbackData = (model: HasParts, partId: string): {
  correctResponse: Response;
  incorrectResponse: Response;
  targetedResponses: Response[];
} => ({
  correctResponse: getCorrectResponse(model, partId),
  incorrectResponse: getIncorrectResponse(model, partId),
  targetedResponses: findTargetedResponses(model, partId),
});

export const correctChoiceIdsForModel = (model: { authoring: { correct?: [ChoiceId[], string] } }) =>
  model.authoring.correct ? getCorrectChoiceIds(model as any) : [];
