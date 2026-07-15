import React from 'react';
import { PreviewContext } from 'components/activities/types';
import {
  getPreviewCustomizationCopy,
  usePreviewCustomizationState,
} from 'components/instructor_preview/preview_customization_store';
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

const TrashActionIcon: React.FC<{ className?: string }> = ({ className = 'h-4 w-4' }) => (
  <svg
    aria-hidden="true"
    className={className}
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <path
      d="M3 6H5H21"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path
      d="M19 6V20C19 20.5304 18.7893 21.0391 18.4142 21.4142C18.0391 21.7893 17.5304 22 17 22H7C6.46957 22 5.96086 21.7893 5.58579 21.4142C5.21071 21.0391 5 20.5304 5 20V6M8 6V4C8 3.46957 8.21071 2.96086 8.58579 2.58579C8.96086 2.21071 9.46957 2 10 2H14C14.5304 2 15.0391 2.21071 15.4142 2.58579C15.7893 2.96086 16 3.46957 16 4V6"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path
      d="M10 11V17"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path
      d="M14 11V17"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

const RestoreActionIcon: React.FC<{ className?: string }> = ({ className = 'h-4 w-4' }) => (
  <svg
    aria-hidden="true"
    className={className}
    viewBox="0 0 20 20"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <path
      d="M3.33301 9.16667C3.33301 12.3883 5.94468 15 9.16634 15C12.388 15 14.9997 12.3883 14.9997 9.16667C14.9997 5.94501 12.388 3.33334 9.16634 3.33334C7.24384 3.33334 5.53848 4.2628 4.47595 5.69884"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path
      d="M5.00033 1.66666L5.00033 5.83332L9.16699 5.83332"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

const actionButtonClasses = (kind: 'remove' | 'restore', disabled = false) => {
  const shared =
    'inline-flex items-center gap-2 rounded-[6px] border bg-Surface-surface-primary px-4 py-2 font-open-sans text-[14px] font-semibold leading-4 tracking-normal shadow-[0px_2px_4px_rgba(0,52,99,0.10)] transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:pointer-events-none';

  if (disabled) {
    return `${shared} border-Fill-Accent-fill-accent-muted text-Text-text-low-alpha`;
  }

  if (kind === 'remove') {
    return `${shared} border-Border-border-danger text-Specially-Tokens-Text-text-button-pill-muted hover:bg-[rgba(255,64,64,0.08)] dark:border-Border-border-danger dark:text-[#FFB5B7] dark:hover:bg-[rgba(255,64,64,0.18)] focus-visible:outline-Border-border-danger`;
  }

  return `${shared} bg-transparent border-[#8AB8E5] text-Text-text-button hover:bg-[#EEF6FF] hover:text-Text-text-button-hover dark:bg-transparent dark:border-[#4C82B8] dark:text-[#9FD0FF] dark:hover:bg-[#16395C] dark:hover:text-[#D7ECFF] focus-visible:outline-[#8AB8E5]`;
};

export const ActivityPreviewCard: React.FC<Props> = ({
  previewContext,
  children,
  detailTabs = [],
  detailsHeader,
  defaultExpanded = false,
}) => {
  const [expanded, setExpanded] = React.useState(defaultExpanded);
  const [activeTabId, setActiveTabId] = React.useState(detailTabs[0]?.id ?? '');
  const { state, begin } = usePreviewCustomizationState(previewContext.customizationTarget, {
    disposition:
      previewContext.actions?.[0]?.kind === 'restore' || previewContext.visualState === 'removed'
        ? 'removed'
        : 'included',
    canToggle: !previewContext.actions?.[0]?.disabled,
  });
  const action = state.disposition === 'removed' ? 'restore' : 'remove';
  const showRemovedTreatment =
    state.disposition === 'removed' && previewContext.customizationTarget.kind !== 'bank_candidate';
  const visualState = showRemovedTreatment ? 'removed' : 'default';
  const actionCopy =
    previewContext.canCustomize && (previewContext.actions?.length ?? 0) > 0
      ? getPreviewCustomizationCopy()
      : null;
  const statusPill = showRemovedTreatment
    ? { kind: 'removed' as const, label: (actionCopy ?? getPreviewCustomizationCopy()).removed }
    : undefined;
  const isSubmitting = state.pendingAction !== null;
  const detailsRegionId = React.useMemo(
    () => `${previewContext.activityHtmlId}-preview-details`,
    [previewContext.activityHtmlId],
  );
  const cardClasses =
    visualState === 'removed'
      ? 'relative h-full bg-Surface-surface-secondary-muted before:absolute before:inset-y-0 before:left-0 before:w-[6px] before:bg-Border-border-danger'
      : '';

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

  const headerActions = actionCopy ? (
    <div className="flex flex-wrap items-center gap-2">
      <button
        type="button"
        disabled={!state.canToggle || isSubmitting}
        aria-busy={isSubmitting}
        className={actionButtonClasses(action, !state.canToggle || isSubmitting)}
        onClick={() => {
          if (!state.canToggle || isSubmitting) {
            return;
          }

          begin(action);
          window.dispatchEvent(
            new CustomEvent('oli:preview-customization', {
              detail: {
                action,
                target: previewContext.customizationTarget,
              },
            }),
          );
        }}
      >
        {action === 'remove' ? <TrashActionIcon /> : <RestoreActionIcon />}
        {isSubmitting ? actionCopy.pending : actionCopy[action]}
      </button>
    </div>
  ) : null;

  return (
    <article className={`p-6 ${cardClasses}`}>
      <div className="flex flex-col gap-4">
        <PreviewHeader
          activityTypeLabel={previewContext.activityTypeLabel}
          title={previewContext.title}
          points={previewContext.points}
          actions={headerActions}
          statusPill={statusPill}
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
                  idPrefix={previewContext.activityHtmlId}
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
