import React from 'react';
import { usePreviewElementContext } from 'components/activities/PreviewElementProvider';
import { ActivityPreviewCard } from 'components/activities/common/preview/ActivityPreviewCard';
import { PreviewHintsPanel } from 'components/activities/common/preview/PreviewHintsPanel';
import { PreviewQuestionStem } from 'components/activities/common/preview/PreviewQuestionStem';
import { PreviewTab } from 'components/activities/common/preview/types';
import { DirectedDiscussionActivitySchema } from './schema';

const ParticipationPanel: React.FC<{ model: DirectedDiscussionActivitySchema }> = ({ model }) => {
  const rows = [
    ['Required number of posts', model.participation.minPosts],
    ['Maximum number of posts', model.participation.maxPosts],
    ['Required number of replies', model.participation.minReplies],
    ['Maximum number of replies', model.participation.maxReplies],
    ['Maximum number of words', model.maxWords || model.participation.maxWordLength],
  ];

  return (
    <section className="flex flex-col gap-4">
      <dl className="mb-0 flex flex-col gap-4">
        {rows.map(([label, value]) => (
          <div key={label} className="flex flex-col gap-2">
            <dt className="text-sm font-semibold leading-5 text-Text-text-medium">{label}:</dt>
            <dd className="mb-0 rounded-lg border border-Border-border-default bg-Specially-Tokens-Fill-fill-input-focused px-4 py-3 text-base leading-7 text-Text-text-high">
              {value}
            </dd>
          </div>
        ))}
      </dl>
    </section>
  );
};

export const DirectedDiscussionPreview: React.FC = () => {
  const { model, previewContext } = usePreviewElementContext<DirectedDiscussionActivitySchema>();
  const part = model.authoring.parts[0];
  const detailTabs: PreviewTab[] = [
    {
      id: 'participation',
      label: 'Participation',
      content: <ParticipationPanel model={model} />,
    },
    {
      id: 'hints',
      label: 'Hints',
      content: <PreviewHintsPanel hints={part?.hints || []} />,
    },
  ];

  return (
    <ActivityPreviewCard previewContext={previewContext} detailTabs={detailTabs}>
      <div className="flex flex-col gap-4">
        <PreviewQuestionStem model={model} />
        <section className="w-full">
          <textarea
            className="min-h-[48px] w-full resize-none rounded-lg border border-Specially-Tokens-Border-border-input bg-Specially-Tokens-Fill-fill-input px-4 py-3.5 text-base leading-7 text-Text-text-high placeholder-Text-text-low"
            value=""
            placeholder="Create your new post..."
            readOnly
          />
        </section>
      </div>
    </ActivityPreviewCard>
  );
};
