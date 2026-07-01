import React from 'react';
import { usePreviewElementContext } from 'components/activities/PreviewElementProvider';
import { ActivityModelSchema } from 'components/activities/types';
import { ActivityPreviewCard } from './ActivityPreviewCard';
import { ReadonlyPanel } from './ReadonlyPanel';

export const PreviewPlaceholder: React.FC = () => {
  const { previewContext } = usePreviewElementContext<ActivityModelSchema>();

  return (
    <ActivityPreviewCard previewContext={previewContext}>
      <ReadonlyPanel title="Preview Pending">
        Shared preview infrastructure is in place for this activity. The activity-specific preview
        rendering will be added in the next implementation phase.
      </ReadonlyPanel>
    </ActivityPreviewCard>
  );
};
