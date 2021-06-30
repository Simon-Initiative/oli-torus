import { getByIdUnsafe } from 'components/activities/ordering/utils';
import { HasHints } from 'components/activities/types';
import { ID } from 'data/content/model';

export const getHints = (model: HasHints) => model.authoring.parts[0].hints;
export const getHint = (model: HasHints, id: ID) => getByIdUnsafe(getHints(model), id);
export const getDeerInHeadlightsHint = (model: HasHints) => getHints(model)[0];
export const getCognitiveHints = (model: HasHints) =>
  getHints(model).slice(1, getHints(model).length - 1);
export const getBottomOutHint = (model: HasHints) => getHints(model)[getHints(model).length - 1];
