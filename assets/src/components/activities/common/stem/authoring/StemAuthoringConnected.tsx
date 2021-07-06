import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import { StemAuthoring } from 'components/activities/common/stem/authoring/StemAuthoring';
import React from 'react';

export const StemAuthoringConnected: React.FC = () => {
  const { model, dispatch } = useAuthoringElementContext();
  return (
    <StemAuthoring
      stem={model.stem}
      onEdit={(content) => dispatch(StemActions.editStemAndPreviewText(content))}
    />
  );
};
