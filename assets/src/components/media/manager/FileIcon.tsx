import * as React from 'react';
import { getFileExtensionGlyph, getFileExtensionColor } from './utils';

export interface FileIconProps {
  className?: string;
  filename: string;
  extension: string;
  url: string;
}

/**
 * FileIcon React Stateless FileIcon
 */
export const FileIcon: React.StatelessComponent<FileIconProps> = ({
  // eslint-disable-next-line
  className,
  // eslint-disable-next-line
  filename,
  // eslint-disable-next-line
  extension,
  // eslint-disable-next-line
  url,
}) => {
  const extColor = getFileExtensionColor(extension);
  const extGlyph = getFileExtensionGlyph(extension);

  return (
    <div className={`media-icon ${className || ''}`} style={{ padding: 5 }}>
      <svg x="0" y="0" width="100%" height="80%" viewBox="0, 0, 512, 512">
        <defs>
          <linearGradient
            id="Gradient_1"
            gradientUnits="userSpaceOnUse"
            x1="368.119"
            y1="860.572"
            x2="368.119"
            y2="96.071"
            gradientTransform="matrix(1, 0, 0, 1, -114.048, -59.064)"
          >
            <stop offset="0" stopColor="#FFFFFF" />
            <stop offset="1" stopColor="#F3F3F3" />
          </linearGradient>
          <linearGradient
            id="Gradient_2"
            gradientUnits="userSpaceOnUse"
            x1="496.609"
            y1="245.199"
            x2="496.609"
            y2="68.325"
            gradientTransform="matrix(1, 0, 0, 1, -114.048, -59.064)"
          >
            <stop offset="0" stopColor="#FFFFFF" />
            <stop offset="0" stopColor="#FFFFFF" />
            <stop offset="0" stopColor="#FFFFFF" />
            <stop offset="1" stopColor="#F2F2F2" />
          </linearGradient>
        </defs>
        <g id="Layer_1">
          <g id="body">
            <path
              d={`M441.629,497.755 C441.629,505.036 435.669,511 428.37,511 C428.37,511 83.63,511 \
                  83.63,511 C76.338,511 70.371,505.036 70.371,497.755 C70.371,497.755 \
                  70.371,14.576 70.371,14.576 C70.371,7.295 76.338,1.331 83.63,1.331 \
                  C83.63,1.331 325.611,1.331 325.611,1.331 C325.611,1.331 441.629,120.479 \
                  441.629,120.479 C441.629,120.479 441.629,497.755 441.629,497.755 z`.replace(
                /\s+/,
                '',
              )}
              fill="url(#Gradient_1)"
            />
            <path
              d={`M441.629,497.755 C441.629,505.036 435.669,511 428.37,511 C428.37,511 83.63,511 \
                  83.63,511 C76.338,511 70.371,505.036 70.371,497.755 C70.371,497.755 \
                  70.371,14.576 70.371,14.576 C70.371,7.295 76.338,1.331 83.63,1.331 C83.63,1.331 \
                  325.611,1.331 325.611,1.331 C325.611,1.331 441.629,120.479 441.629,120.479 \
                  C441.629,120.479 441.629,497.755 441.629,497.755 z`.replace(/\s+/, '')}
              fillOpacity="0"
              stroke="#000000"
              strokeWidth="1"
            />
          </g>
          <g id="fold">
            <path
              d={`M326.343,1 C326.343,1 440.544,118.923 440.544,118.923 C440.544,118.923 \
                  325.773,118.923 325.773,118.923 C325.773,118.923 326.343,1 326.343,1 z`.replace(
                /\s+/,
                '',
              )}
              fill="url(#Gradient_2)"
            />
            <path
              d={`M326.343,1 C326.343,1 440.544,118.923 440.544,118.923 C440.544,118.923 \
                  325.773,118.923 325.773,118.923 C325.773,118.923 326.343,1 326.343,1 z`.replace(
                /\s+/,
                '',
              )}
              fillOpacity="0"
              stroke="#000000"
              strokeWidth="1"
            />
          </g>
          {extension ? (
            <g id="label" transform="translate(-30)">
              <path
                d="M37.454,58 L312.454,58 L312.454,188 L37.454,188 L37.454,58 z"
                fill={extColor}
              />
              <text transform="matrix(1, 0, 0, 1, 175.454, 123)">
                <tspan
                  x="-72.536"
                  y="26.5"
                  fontFamily="HelveticaNeue-Bold"
                  // eslint-disable-next-line
                  fontSize="72"
                  fill="#FFFFFF"
                >
                  {extension.toUpperCase()}
                </tspan>
              </text>
            </g>
          ) : null}
          <g transform="translate(-25)">{extGlyph}</g>
        </g>
      </svg>
    </div>
  );
};
