import { getPartById } from './utils';
import { HasParts, PostUndoable, makeFeedback } from 'components/activities/types';

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
