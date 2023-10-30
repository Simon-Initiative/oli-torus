import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { HasParts, RichText } from 'components/activities/types';
import { SlateOrMarkdownEditor } from 'components/editing/SlateOrMarkdownEditor';
import {
  getExplanationContent,
  getExplanationEditor,
  getExplanationTextDirection,
  setExplanationContent,
  setExplanationEditor,
  setExplanationTextDirection,
} from 'data/activities/model/explanation';
import { EditorType } from 'data/content/resource';

interface Props {
  partId: string;
}
export const Explanation: React.FC<Props> = (props) => {
  const { dispatch, model, projectSlug } = useAuthoringElementContext<HasParts>();
  return (
    <SlateOrMarkdownEditor
      placeholder="Explanation"
      content={getExplanationContent(model, props.partId)}
      onEdit={(content: RichText) => dispatch(setExplanationContent(props.partId, content))}
      onEditorTypeChange={(editor: EditorType) =>
        dispatch(setExplanationEditor(props.partId, editor))
      }
      editMode={true}
      editorType={getExplanationEditor(model, props.partId)}
      allowBlockElements={true}
      projectSlug={projectSlug}
      textDirection={getExplanationTextDirection(model, props.partId)}
      onChangeTextDirection={(textDirection) =>
        dispatch(setExplanationTextDirection(props.partId, textDirection))
      }
    />
  );
};
