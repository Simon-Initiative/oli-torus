import { HasParts, makeFeedback, PostUndoable } from 'components/activities/types';
import { getPartById } from './utils';

export const getExplanation = (model: HasParts, partId: string) => {
  return getPartById(model, partId).explanation;
};

export const getExplanationContent = (model: HasParts, partId: string) => {
  const explanation = getExplanation(model, partId);
  return explanation ? explanation.content : makeFeedback('').content;
};

export const setExplanationContent = (partId: string, content: any) => {
  return (model: HasParts, _post: PostUndoable) => {
    const part = getPartById(model, partId);
    if (part.explanation == undefined) {
      part.explanation = makeFeedback('');
    }

    part.explanation.content = content;
  };
};
