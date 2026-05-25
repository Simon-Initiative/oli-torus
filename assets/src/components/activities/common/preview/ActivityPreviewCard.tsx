import React from 'react';
import { PreviewContext } from 'components/activities/types';
import { LearningObjectiveList } from './LearningObjectiveList';
import { PreviewDetailsToggle } from './PreviewDetailsToggle';
import { PreviewHeader } from './PreviewHeader';
import { PreviewTabs } from './PreviewTabs';
import { PreviewTab } from './types';

interface Props {
  previewContext: PreviewContext;
  children: React.ReactNode;
  detailTabs?: PreviewTab[];
  detailsHeader?: React.ReactNode;
  defaultExpanded?: boolean;
}

export const ActivityPreviewCard: React.FC<Props> = ({
  previewContext,
  children,
  detailTabs = [],
  detailsHeader,
  defaultExpanded = false,
}) => {
  const [expanded, setExpanded] = React.useState(defaultExpanded);
  const [activeTabId, setActiveTabId] = React.useState(detailTabs[0]?.id ?? '');
  const detailsRegionId = React.useMemo(
    () => `${previewContext.activityHtmlId}-preview-details`,
    [previewContext.activityHtmlId],
  );

  React.useEffect(() => {
    if (detailTabs.length === 0) {
      setExpanded(false);
      setActiveTabId('');
      return;
    }

    if (!detailTabs.some((tab) => tab.id === activeTabId)) {
      setActiveTabId(detailTabs[0].id);
    }
  }, [activeTabId, detailTabs]);

  return (
    <article className="p-6">
      <div className="flex flex-col gap-4">
        <PreviewHeader
          activityTypeLabel={previewContext.activityTypeLabel}
          title={previewContext.title}
          points={previewContext.points}
        />

        <div>{children}</div>

        {detailTabs.length > 0 && (
          <>
            <PreviewDetailsToggle
              expanded={expanded}
              controlsId={detailsRegionId}
              onToggle={() => setExpanded((current) => !current)}
            />

            {expanded && (
              <div id={detailsRegionId}>
                {detailsHeader ? <div className="mb-4">{detailsHeader}</div> : null}
                <PreviewTabs
                  tabs={detailTabs}
                  activeTabId={activeTabId}
                  onTabChange={setActiveTabId}
                />
              </div>
            )}
          </>
        )}

        <LearningObjectiveList objectives={previewContext.learningObjectives} />
      </div>
    </article>
  );
};
