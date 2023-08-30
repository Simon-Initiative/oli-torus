import { HasParts, Part, PostUndoable, makeFeedback } from 'components/activities/types';
import { getDefaultEditor } from 'components/editing/markdown_editor/markdown_util';
import { EditorType } from 'data/content/resource';
import { getPartById } from './utils';

export const getExplanation = (model: HasParts, partId: string) => {
  return getPartById(model, partId).explanation;
};

export const getExplanationContent = (model: HasParts, partId: string) => {
  const explanation = getExplanation(model, partId);
  return explanation ? explanation.content : makeFeedback('').content;
};

export const getExplanationEditor = (model: HasParts, partId: string): EditorType => {
  const explanation = getExplanation(model, partId);
  return explanation?.editor || getDefaultEditor();
};

type PartWithExplanation = Required<Pick<Part, 'explanation'>> & Part;

const initializeExplanation = (part: Part): PartWithExplanation => {
  if (part.explanation == undefined) {
    part.explanation = makeFeedback('');
    part.explanation.editor = getDefaultEditor();
  }
  return part as PartWithExplanation;
};

export const setExplanationContent = (partId: string, content: any) => {
  return (model: HasParts, _post: PostUndoable) => {
    const part = getPartById(model, partId);
    initializeExplanation(part).explanation.content = content;
  };
};

export const setExplanationEditor = (partId: string, editor: EditorType) => {
  return (model: HasParts, _post: PostUndoable) => {
    const part = getPartById(model, partId);
    initializeExplanation(part).explanation.editor = editor;
  };
};
