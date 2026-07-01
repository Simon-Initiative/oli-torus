import React from 'react';
import { usePreviewElementContext } from 'components/activities/PreviewElementProvider';
import { ActivityPreviewCard } from 'components/activities/common/preview/ActivityPreviewCard';
import { PreviewExplanationPanel } from 'components/activities/common/preview/PreviewExplanationPanel';
import { PreviewHintsPanel } from 'components/activities/common/preview/PreviewHintsPanel';
import { PreviewQuestionStem } from 'components/activities/common/preview/PreviewQuestionStem';
import { PreviewTab } from 'components/activities/common/preview/types';
import { LikertTable } from './Sections/LikertTable';
import { LikertModelSchema } from './schema';

export const LikertPreview: React.FC = () => {
  const { model, previewContext, writerContext } = usePreviewElementContext<LikertModelSchema>();
  const part = model.authoring.parts[0];
  const detailTabs: PreviewTab[] = [
    {
      id: 'hints',
      label: 'Hints',
      content: <PreviewHintsPanel hints={part?.hints || []} />,
    },
    {
      id: 'explanation',
      label: 'Explanation',
      content: <PreviewExplanationPanel model={model} partId={part.id} />,
    },
  ];

  return (
    <ActivityPreviewCard previewContext={previewContext} detailTabs={detailTabs}>
      <div className="flex flex-col gap-4">
        <PreviewQuestionStem model={model} />
        <LikertTable
          model={model}
          isSelected={() => false}
          onSelect={() => null}
          disabled
          context={writerContext}
          interactive={false}
        />
      </div>
    </ActivityPreviewCard>
  );
};
