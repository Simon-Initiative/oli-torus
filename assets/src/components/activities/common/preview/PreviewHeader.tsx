import React from 'react';

interface Props {
  activityTypeLabel: string;
  title?: string;
  points?: number | null;
}

const formatPoints = (points?: number | null) => {
  if (points === null || points === undefined) {
    return null;
  }

  return `${points} ${points === 1 ? 'point' : 'points'}`;
};

export const PreviewHeader: React.FC<Props> = ({ activityTypeLabel, title, points }) => {
  const pointsLabel = formatPoints(points);

  return (
    <header className="flex flex-col gap-2">
      <div className="flex flex-wrap items-center gap-3 text-sm font-normal leading-[21px] text-Text-text-low-alpha">
        <span>{activityTypeLabel}</span>
        {pointsLabel && (
          <>
            <span aria-hidden="true">&bull;</span>
            <span>{pointsLabel}</span>
          </>
        )}
      </div>
      {title && (
        <h3 className="!m-0 text-xl font-semibold leading-[26px] text-Text-text-high">{title}</h3>
      )}
    </header>
  );
};
