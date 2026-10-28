import React from 'react';
import { DrawnLine, bezierPath } from './matching-util';

interface MatchingLinesProps {
  lines: DrawnLine[];
  draft?: { x1: number; y1: number; x2: number; y2: number } | null;
  themeColor: string;
  getLineClassName?: (line: DrawnLine) => string;
  onLineClick?: (line: DrawnLine) => void;
}

const UnlinkBadge: React.FC<{ x: number; y: number; onClick: () => void }> = ({
  x,
  y,
  onClick,
}) => (
  <g
    className="matching-unlink-badge"
    transform={`translate(${x}, ${y})`}
    onClick={(e) => {
      e.stopPropagation();
      onClick();
    }}
  >
    <circle className="matching-unlink-bg" r={10} cx={0} cy={0} />
    <path className="matching-unlink-x" d="M -3.5 -3.5 L 3.5 3.5 M 3.5 -3.5 L -3.5 3.5" />
  </g>
);

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
    {lines.map((line) => {
      const className = `matching-line${getLineClassName ? ` ${getLineClassName(line)}` : ''}${
        onLineClick ? ' matching-line--clickable' : ''
      }`;
      const handleClick = onLineClick
        ? (e: React.MouseEvent) => {
            e.stopPropagation();
            onLineClick(line);
          }
        : undefined;

      if (!onLineClick) {
        return (
          <path
            key={line.key}
            className={className}
            d={bezierPath(line.x1, line.y1, line.x2, line.y2)}
            fill="none"
            stroke={themeColor}
            strokeWidth={3}
            strokeLinecap="round"
            pointerEvents="none"
          />
        );
      }

      return (
        <g key={line.key} className="matching-line-group" onClick={handleClick}>
          {/* Invisible wider hit target */}
          <path
            d={bezierPath(line.x1, line.y1, line.x2, line.y2)}
            fill="none"
            stroke="transparent"
            strokeWidth={14}
            strokeLinecap="round"
            pointerEvents="stroke"
          />
          <path
            className={className}
            d={bezierPath(line.x1, line.y1, line.x2, line.y2)}
            fill="none"
            stroke={themeColor}
            strokeWidth={3}
            strokeLinecap="round"
            pointerEvents="stroke"
          />
          <UnlinkBadge x={line.x2} y={line.y2} onClick={() => onLineClick(line)} />
        </g>
      );
    })}
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
