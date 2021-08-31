import { getByUnsafe, getPartById } from 'components/activities/common/authoring/utils';
import { HasHints } from 'components/activities/types';
import { ID } from 'data/content/model';

export const hintsByPart = (partId: string) => `$.authoring.parts[?(@.id==${partId})].hints`;

export const getHints = (model: HasHints, partId: string) => getPartById(model, partId).hints;
export const getHint = (model: HasHints, id: ID, partId: string) =>
  getByUnsafe(getHints(model, partId), (h) => h.id === id);

// Native OLI activities split out hints into three types:
// a. (0-1) Deer in headlights (re-explain the problem for students who don't understand the prompt)
// b. (0-many) Cognitive hints (explain how to solve the problem)
// c. (0-1) Bottom out hint (explain the answer)
// These hints are saved in-order.
export const getDeerInHeadlightsHint = (model: HasHints, partId: string) =>
  getHints(model, partId)[0];
export const getCognitiveHints = (model: HasHints, partId: string) =>
  getHints(model, partId).slice(1, getHints(model, partId).length - 1);
export const getBottomOutHint = (model: HasHints, partId: string) =>
  getHints(model, partId)[getHints(model, partId).length - 1];
