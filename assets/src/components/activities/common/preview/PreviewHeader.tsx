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

  return `${points} ${points === 1 ? 'pt' : 'pts'}`;
};

export const PreviewHeader: React.FC<Props> = ({ activityTypeLabel, title, points }) => {
  const pointsLabel = formatPoints(points);

  return (
    <header className="flex items-start justify-between gap-3 border-b border-gray-200 pb-3">
      <div className="min-w-0">
        <div className="text-xs font-semibold uppercase tracking-wide text-gray-500">
          {activityTypeLabel}
        </div>
        {title && <h3 className="mb-0 mt-1 text-lg font-semibold text-gray-900">{title}</h3>}
      </div>
      {pointsLabel && (
        <div className="shrink-0 rounded-full border border-gray-200 bg-gray-50 px-3 py-1 text-sm font-semibold text-gray-700">
          {pointsLabel}
        </div>
      )}
    </header>
  );
};
