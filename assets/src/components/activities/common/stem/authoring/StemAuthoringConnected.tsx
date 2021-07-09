import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import { StemAuthoring as Component } from 'components/activities/common/stem/authoring/StemAuthoring';
import { HasStem } from 'components/activities/types';
import React from 'react';

export const Stem: React.FC = () => {
  const { model, dispatch } = useAuthoringElementContext<HasStem>();
  return (
    <Component
      stem={model.stem}
      onEdit={(content) => dispatch(StemActions.editStemAndPreviewText(content))}
    />
  );
};
