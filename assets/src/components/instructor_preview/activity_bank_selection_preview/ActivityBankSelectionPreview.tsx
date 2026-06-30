import React from 'react';
import { PreviewHeader } from 'components/activities/common/preview/PreviewHeader';
import { PreviewAction, PreviewStatusPill, PreviewVisualState } from 'components/activities/types';
import { ArrowRight } from 'components/misc/icons/Icons';

interface CustomizationTarget {
  kind: 'bank_selection';
  pageResourceId: number;
  selectionId: string;
}

interface SampleActivity {
  activityResourceId: number;
  title: string;
  model: unknown;
  previewElement: string;
  renderMode?: 'preview' | 'authoring_fallback';
  previewContext: SampleActivityPreviewContext;
}

interface SampleActivityPreviewContext {
  sectionSlug: string;
  pageResourceId: number;
  pageRevisionSlug: string;
  activityResourceId: number;
  activityHtmlId: string;
  activityTypeSlug?: string;
  activityTypeLabel: string;
  title: string;
  points?: number;
  learningObjectives?: string[];
  canCustomize?: boolean;
  actions?: PreviewAction[];
  visualState?: PreviewVisualState;
  statusPill?: PreviewStatusPill | null;
  customizationTarget?: unknown;
  [key: string]: unknown;
}

export interface ActivityBankSelectionPreviewPayload {
  id: string;
  title: string;
  selectedCount: number;
  availableCount: number;
  pointsPerActivity: number;
  selectionCriteriaHtml?: string | null;
  manageQuestionsUrl?: string | null;
  sampleActivity?: SampleActivity | null;
  canCustomize: boolean;
  actions?: PreviewAction[];
  visualState?: PreviewVisualState;
  statusPill?: PreviewStatusPill | null;
  customizationTarget: CustomizationTarget;
}

interface Props {
  payload: ActivityBankSelectionPreviewPayload;
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
    <path d="M10 11V17" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    <path d="M14 11V17" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
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

const actionButtonClasses = (kind: 'remove' | 'restore') => {
  const shared =
    'inline-flex items-center gap-2 rounded-[6px] border bg-Surface-surface-primary px-4 py-2 font-open-sans text-[14px] font-semibold leading-4 tracking-normal shadow-[0px_2px_4px_rgba(0,52,99,0.10)] transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:cursor-wait disabled:opacity-70';

  if (kind === 'remove') {
    return `${shared} border-Border-border-danger text-Specially-Tokens-Text-text-button-pill-muted hover:bg-[rgba(255,64,64,0.08)] dark:border-Border-border-danger dark:text-[#FFB5B7] dark:hover:bg-[rgba(255,64,64,0.18)] focus-visible:outline-Border-border-danger`;
  }

  return `${shared} bg-transparent border-[#8AB8E5] text-Text-text-button hover:bg-[#EEF6FF] hover:text-Text-text-button-hover dark:bg-transparent dark:border-[#4C82B8] dark:text-[#9FD0FF] dark:hover:bg-[#16395C] dark:hover:text-[#D7ECFF] focus-visible:outline-[#8AB8E5]`;
};

const pluralize = (count: number, singular: string, plural: string) =>
  `${count} ${count === 1 ? singular : plural}`;

const labelTextClasses = 'font-open-sans text-[14px] font-bold leading-4 text-Text-text-high';

const matchesCustomizationTarget = (
  expectedTarget: CustomizationTarget,
  replyTarget?: Partial<CustomizationTarget>,
) =>
  !!replyTarget &&
  replyTarget.kind === expectedTarget.kind &&
  replyTarget.pageResourceId === expectedTarget.pageResourceId &&
  replyTarget.selectionId === expectedTarget.selectionId;

const SampleActivityPreview: React.FC<{
  sample?: SampleActivity | null;
  visualState: PreviewVisualState;
}> = ({ sample, visualState }) => {
  const sampleContainerClasses =
    visualState === 'removed' ? 'bg-Surface-surface-secondary-muted' : 'bg-Surface-surface-primary';

  if (!sample?.previewElement) {
    return (
      <div
        className={`rounded-lg border border-Border-border-default p-4 text-sm text-Text-text-low ${sampleContainerClasses}`}
      >
        No sample question is available for this activity bank selection.
      </div>
    );
  }

  const activityElement =
    sample.renderMode === 'authoring_fallback'
      ? React.createElement(sample.previewElement, {
          model: JSON.stringify(sample.model),
          authoringcontext: JSON.stringify({ variables: {}, previewMode: 'instructor' }),
          editmode: 'false',
          mode: 'instructor_preview',
          activity_id: sample.previewContext.activityHtmlId,
          activityId: sample.activityResourceId,
          section_slug: sample.previewContext.sectionSlug,
          projectSlug: sample.previewContext.sectionSlug,
        })
      : React.createElement(sample.previewElement, {
          model: JSON.stringify(sample.model),
          previewcontext: JSON.stringify(sample.previewContext),
          mode: 'preview',
          activity_id: sample.previewContext.activityHtmlId,
          activityId: sample.activityResourceId,
          section_slug: sample.previewContext.sectionSlug,
          projectSlug: sample.previewContext.sectionSlug,
        });

  if (sample.renderMode === 'authoring_fallback') {
    return (
      <div
        className={`overflow-hidden rounded-lg border border-Border-border-default p-6 ${sampleContainerClasses}`}
      >
        <div className="flex flex-col gap-4">
          <PreviewHeader
            activityTypeLabel={sample.previewContext.activityTypeLabel}
            title={sample.previewContext.title}
            points={sample.previewContext.points}
            statusPill={sample.previewContext.statusPill ?? undefined}
          />
          <div>{activityElement}</div>
        </div>
      </div>
    );
  }

  return (
    <div
      className={`overflow-hidden rounded-lg border border-Border-border-default ${sampleContainerClasses}`}
    >
      {activityElement}
    </div>
  );
};

export const ActivityBankSelectionPreview: React.FC<Props> = ({ payload }) => {
  const [actions, setActions] = React.useState(payload.actions ?? []);
  const [visualState, setVisualState] = React.useState(payload.visualState ?? 'default');
  const [statusPill, setStatusPill] = React.useState(payload.statusPill ?? undefined);
  const [availableCount, setAvailableCount] = React.useState(payload.availableCount);
  const [isSubmitting, setIsSubmitting] = React.useState(false);

  React.useEffect(() => {
    setActions(payload.actions ?? []);
    setVisualState(payload.visualState ?? 'default');
    setStatusPill(payload.statusPill ?? undefined);
    setAvailableCount(payload.availableCount);
  }, [payload]);

  React.useEffect(() => {
    const handleCustomizationReply = (event: Event) => {
      const detail = (event as CustomEvent).detail;

      if (!matchesCustomizationTarget(payload.customizationTarget, detail?.target)) {
        return;
      }

      setIsSubmitting(false);

      if (detail.ok && Array.isArray(detail.actions)) {
        setActions(detail.actions);
      }

      if (detail.ok && Object.prototype.hasOwnProperty.call(detail, 'visualState')) {
        setVisualState(detail.visualState ?? 'default');
      }

      if (detail.ok && Object.prototype.hasOwnProperty.call(detail, 'statusPill')) {
        setStatusPill(detail.statusPill ?? undefined);
      }

      if (detail.ok && typeof detail.availableCount === 'number') {
        setAvailableCount(detail.availableCount);
      }
    };

    window.addEventListener('oli:preview-customization:reply', handleCustomizationReply);

    return () => {
      window.removeEventListener('oli:preview-customization:reply', handleCustomizationReply);
    };
  }, [payload.customizationTarget]);

  const headerActions =
    payload.canCustomize && actions.length > 0 ? (
      <div className="flex flex-wrap items-center gap-2">
        {actions.map((action) => (
          <button
            key={action.kind}
            type="button"
            disabled={isSubmitting}
            className={actionButtonClasses(action.kind)}
            onClick={() => {
              setIsSubmitting(true);
              window.dispatchEvent(
                new CustomEvent('oli:preview-customization', {
                  detail: {
                    action: action.kind,
                    target: payload.customizationTarget,
                  },
                }),
              );
            }}
          >
            {action.kind === 'remove' ? <TrashActionIcon /> : <RestoreActionIcon />}
            {isSubmitting ? 'Updating...' : action.label}
          </button>
        ))}
      </div>
    ) : null;

  const manageQuestionsAction = payload.manageQuestionsUrl ? (
    <a
      href={payload.manageQuestionsUrl}
      className="inline-flex items-center justify-center gap-2 rounded-[6px] bg-Fill-Buttons-fill-primary px-4 py-2 font-open-sans text-[14px] font-semibold leading-4 !text-Text-text-white no-underline shadow-[0px_2px_4px_rgba(0,52,99,0.10)] transition-colors visited:!text-Text-text-white hover:bg-Fill-Buttons-fill-primary-hover hover:!text-Text-text-white hover:no-underline focus-visible:!text-Text-text-white focus-visible:no-underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
    >
      Manage questions
      <ArrowRight className="h-4 w-4" />
    </a>
  ) : null;

  const cardClasses =
    visualState === 'removed'
      ? 'relative bg-Surface-surface-secondary-muted before:absolute before:inset-y-0 before:left-0 before:w-[6px] before:bg-Border-border-danger'
      : 'bg-Surface-surface-primary';

  return (
    <article className={`p-[25px] font-open-sans ${cardClasses}`}>
      <div className="flex flex-col gap-[18px]">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div className="flex min-w-0 flex-col">
            <div className="flex flex-wrap items-center gap-2">
              <div
                role="heading"
                aria-level={3}
                className="font-open-sans text-[26px] font-semibold leading-[31.2px] text-Text-text-high"
              >
                {payload.title}
              </div>
              {statusPill ? (
                <span className="inline-flex items-center rounded-full border border-Border-border-danger bg-Fill-fill-danger px-3 py-1 pr-4 font-open-sans text-[16px] font-bold leading-4 text-Text-text-danger">
                  {statusPill.label}
                </span>
              ) : null}
            </div>
          </div>

          {headerActions}
        </div>

        <div className="flex flex-col gap-[10px]">
          <p className="m-0 font-open-sans text-[16px] font-bold leading-4 text-Text-text-high">
            {pluralize(availableCount, 'question', 'questions')} available
          </p>

          <div className="flex min-h-[42px] flex-wrap items-center gap-x-[34px] gap-y-2 font-open-sans text-[14px] font-semibold leading-4 text-Text-text-high">
            <div>
              <span className={labelTextClasses}>Selects:</span>{' '}
              {pluralize(payload.selectedCount, 'question', 'questions')}
            </div>
            <div>
              <span className={labelTextClasses}>Points per question:</span>{' '}
              {payload.pointsPerActivity}
            </div>
          </div>

          {payload.selectionCriteriaHtml ? (
            <div dangerouslySetInnerHTML={{ __html: payload.selectionCriteriaHtml }} />
          ) : null}
        </div>

        {manageQuestionsAction ? <div className="mt-1">{manageQuestionsAction}</div> : null}

        <hr className="m-0 border-0 border-t border-Border-border-default" />

        <section aria-labelledby={`${payload.id}-sample-heading`} className="flex flex-col gap-3">
          <div
            id={`${payload.id}-sample-heading`}
            role="heading"
            aria-level={4}
            className="font-open-sans text-[16px] font-bold leading-4 text-Text-text-high"
          >
            Sample question from this selection:
          </div>
          <SampleActivityPreview sample={payload.sampleActivity} visualState={visualState} />
        </section>
      </div>
    </article>
  );
};
