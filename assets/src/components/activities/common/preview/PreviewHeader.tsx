import React from 'react';

interface Props {
  activityTypeLabel: string;
  title?: string;
  points?: number | null;
  actions?: React.ReactNode;
  statusPill?: {
    kind: 'removed';
    label: string;
  };
}

const formatPoints = (points?: number | null) => {
  if (points === null || points === undefined) {
    return null;
  }

  return `${points} ${points === 1 ? 'point' : 'points'}`;
};

export const PreviewHeader: React.FC<Props> = ({
  activityTypeLabel,
  title,
  points,
  actions,
  statusPill,
}) => {
  const pointsLabel = formatPoints(points);

  return (
    <header className="flex flex-col gap-3">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between sm:gap-4">
        <div className="flex min-w-0 flex-col gap-2">
          <div className="flex flex-wrap items-center gap-3 text-sm font-normal leading-[21px] text-Text-text-low-alpha">
            <span>{activityTypeLabel}</span>
            {pointsLabel && (
              <>
                <span aria-hidden="true">&bull;</span>
                <span>{pointsLabel}</span>
              </>
            )}
          </div>
          {(title || statusPill?.kind === 'removed') && (
            <div className="flex flex-wrap items-center gap-3">
              {title ? (
                <h3 className="!m-0 text-xl font-semibold leading-[26px] text-Text-text-high">
                  {title}
                </h3>
              ) : null}
              {statusPill?.kind === 'removed' ? (
                <span className="inline-flex items-center rounded-full border border-Border-border-danger bg-[rgba(255,64,64,0.08)] px-4 py-1 font-open-sans text-[14px] font-semibold leading-4 tracking-normal text-[#C91414] dark:bg-[rgba(255,64,64,0.16)] dark:text-[#FFB5B7]">
                  {statusPill.label}
                </span>
              ) : null}
            </div>
          )}
        </div>
        {actions ? <div className="w-full sm:w-auto sm:shrink-0">{actions}</div> : null}
      </div>
    </header>
  );
};
