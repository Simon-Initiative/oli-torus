import { getByIdUnsafe } from 'components/activities/common/authoring/utils';
import { HasParts } from 'components/activities/types';

// Responses
export const getResponses = (model: HasParts) => model.authoring.parts[0].responses;
export const getResponse = (model: HasParts, id: string) => getByIdUnsafe(getResponses(model), id);
