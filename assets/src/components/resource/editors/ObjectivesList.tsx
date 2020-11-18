import * as React from 'react';

export interface ObjectivesListProps {
  objectives: string[];
}

export const ObjectivesList = (props: ObjectivesListProps) => {
  const className = `objectives-list ${props.objectives.length > 0 ? "with-objectives" : "no-objectives"}`
  return (
    <div className="objectives-list-container">
      <div className={className}>
        {props.objectives.length === 0
          ? (
            <div>
              <i className="las la-exclamation-triangle mr-2 text-warning"></i> This activity doesn't target any objectives. <a href="https://www.cmu.edu/teaching/designteach/design/learningobjectives.html" target="_blank">Learn more</a> about the importance of attaching learning objectives to activities.
            </div>
          )
          : (
            <div>
              <i className="las la-graduation-cap mr-1 text-info"></i> <span className="mr-2">Targeted Objectives:</span>

              {props.objectives.map(o =>
                <span key={o}
                  className="objective-token rbt-token"
                  data-toggle="popover"
                  data-content={o}>
                    {o}
                </span>)}
            </div>
          )
        }
      </div>
    </div>
  );
};
