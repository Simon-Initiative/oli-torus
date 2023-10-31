import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import { StemAuthoring } from 'components/activities/common/stem/authoring/StemAuthoring';
import { HasStem } from 'components/activities/types';

export const Stem: React.FC = () => {
  const { model, dispatch, editMode, projectSlug } = useAuthoringElementContext<HasStem>();
  return (
    <StemAuthoring
      stem={model.stem}
      onEdit={(content) => dispatch(StemActions.editStemAndPreviewText(content))}
      onChangeEditorType={(editorType) => dispatch(StemActions.changeEditorMode(editorType))}
      onChangeTextDirection={(textDirection) =>
        dispatch(StemActions.changeTextDirection(textDirection))
      }
      editMode={editMode}
      projectSlug={projectSlug}
    />
  );
};
