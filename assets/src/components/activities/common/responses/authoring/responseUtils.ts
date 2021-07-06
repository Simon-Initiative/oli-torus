import { getByIdUnsafe } from 'components/activities/common/authoring/utils';
import { HasParts } from 'components/activities/types';
import { Maybe } from 'tsmonad';

// Responses
export const getResponses = (model: HasParts) => model.authoring.parts[0].responses;
export const getResponse = (model: HasParts, id: string) => getByIdUnsafe(getResponses(model), id);

export const getCorrectResponse = (model: HasParts) => {
  return Maybe.maybe(getResponses(model).find((r) => r.score === 1)).valueOrThrow(
    new Error('Could not find correct response'),
  );
};
export const getIncorrectResponse = (model: HasParts) => {
  return Maybe.maybe(getResponses(model).find((r) => r.score === 0)).valueOrThrow(
    new Error('Could not find incorrect response'),
  );
};
