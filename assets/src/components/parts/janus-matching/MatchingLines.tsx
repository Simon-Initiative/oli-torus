import React from 'react';
import { bezierPath, DrawnLine } from './matching-util';

interface MatchingLinesProps {
  lines: DrawnLine[];
  draft?: { x1: number; y1: number; x2: number; y2: number } | null;
  themeColor: string;
  getLineClassName?: (line: DrawnLine) => string;
  onLineClick?: (line: DrawnLine) => void;
}

const MatchingLines: React.FC<MatchingLinesProps> = ({
  lines,
  draft,
  themeColor,
  getLineClassName,
  onLineClick,
}) => (
  <svg
    className={`matching-lines${onLineClick ? ' matching-lines--interactive' : ''}`}
    aria-hidden="true"
  >
    {lines.map((line) => (
      <path
        key={line.key}
        className={`matching-line${getLineClassName ? ` ${getLineClassName(line)}` : ''}${
          onLineClick ? ' matching-line--clickable' : ''
        }`}
        d={bezierPath(line.x1, line.y1, line.x2, line.y2)}
        fill="none"
        stroke={themeColor}
        strokeWidth={3}
        strokeLinecap="round"
        pointerEvents={onLineClick ? 'stroke' : 'none'}
        onClick={
          onLineClick
            ? (e) => {
                e.stopPropagation();
                onLineClick(line);
              }
            : undefined
        }
      />
    ))}
    {draft && (
      <path
        className="matching-line matching-line--draft"
        d={bezierPath(draft.x1, draft.y1, draft.x2, draft.y2)}
        fill="none"
        stroke={themeColor}
        strokeWidth={2.5}
        strokeLinecap="round"
        strokeDasharray="6 4"
        opacity={0.85}
        pointerEvents="none"
      />
    )}
  </svg>
);

export default MatchingLines;
