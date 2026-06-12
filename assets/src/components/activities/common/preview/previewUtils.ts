import { Choice, ChoiceId, HasParts, Part, Response } from 'components/activities/types';
import {
  ResponseMapping,
  findTargetedResponses,
  getCorrectChoiceIds,
  getCorrectResponse,
  getIncorrectResponse,
} from 'data/activities/model/responses';

type ModelWithCorrectChoiceIds = {
  authoring: { correct?: [ChoiceId[], string] };
};

type ModelWithRequiredCorrectChoiceIds = {
  authoring: { correct: [ChoiceId[], string] };
};

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

export const standardFeedbackData = (
  model: HasParts,
  partId: string,
  targetedResponseMappings: ResponseMapping[] = [],
): {
  correctResponse: Response;
  incorrectResponse: Response;
  targetedResponses: Response[];
} => ({
  correctResponse: getCorrectResponse(model, partId),
  incorrectResponse: getIncorrectResponse(model, partId),
  targetedResponses:
    targetedResponseMappings.length > 0
      ? targetedResponseMappings.map((mapping) => mapping.response)
      : findTargetedResponses(model, partId),
});

export const correctChoiceIdsForModel = (model: ModelWithCorrectChoiceIds) =>
  model.authoring.correct ? getCorrectChoiceIds(model as ModelWithRequiredCorrectChoiceIds) : [];
