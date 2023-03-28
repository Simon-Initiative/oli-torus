import * as React from 'react';

import './ObjectivesList.scss';

export interface ObjectivesListProps {
  objectives: string[];
}

export const ObjectivesList = (props: ObjectivesListProps) => {
  const className = `objectives-list ${
    props.objectives.length > 0 ? 'with-objectives' : 'no-objectives'
  }`;
  return (
    <div className="objectives-list-container">
      <div className={className}>
        {props.objectives.length === 0 ? (
          <div>
            <i className="fas fa-exclamation-triangle mr-2 text-warning"></i>
            This activity doesn&apos;t target any objectives.{' '}
            <a
              rel="noreferrer"
              href="https://www.cmu.edu/teaching/designteach/design/learningobjectives.html"
              target="_blank"
            >
              Learn more
            </a>{' '}
            about the importance of attaching learning objectives to activities.
          </div>
        ) : (
          <div className="d-flex flex-row">
            <div className="pr-2">
              <i className="fas fa-graduation-cap text-info"></i>
            </div>

            <div className="flex-grow-1 overflow-hidden">
              {props.objectives.map((o) => (
                <span
                  key={o}
                  className="objective-token rbt-token"
                  data-bs-toggle="popover"
                  data-bs-content={o}
                >
                  {o}
                </span>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
