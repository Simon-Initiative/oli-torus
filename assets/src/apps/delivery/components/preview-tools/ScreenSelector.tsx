/* eslint-disable no-prototype-builtins */
/* eslint-disable react/prop-types */
import React from 'react';

interface ScreenSelectorProps {
  sequence: any;
  navigate: any;
  currentActivity: any;
}
const ScreenSelector: React.FC<ScreenSelectorProps> = ({
  sequence,
  navigate,
  currentActivity,
}: ScreenSelectorProps) => {
  return (
    <div className={`preview-tools-view`}>
      <ol className="list-group list-group-flush">
        {sequence?.map((s: any, i: number) => {
          return (
            <li
              key={i}
              className={`list-group-item pl-5 py-1 list-group-item-action${
                currentActivity?.id === s.sequenceId ? ' active' : ''
              }`}
            >
              <a
                href=""
                className={currentActivity?.id === s.sequenceId ? 'selected' : ''}
                onClick={(e) => {
                  e.preventDefault();
                  navigate(s.sequenceId);
                }}
              >
                {s.sequenceName}
              </a>
            </li>
          );
        })}
      </ol>
    </div>
  );
};

export default ScreenSelector;
