import * as React from 'react';
import { Objectives } from './Objectives';


export interface AbbreviatedActivityProps {
  previewText: string;
  objectives: string[];
}

export const AbbreviatedActivity = (props: AbbreviatedActivityProps) => {

  const label = (props.objectives.length === 0)
    ? <div className="no-objectives">No targeted objectives</div>
    : <div className="with-objectives">Targeted objectives:</div>;

  return (
    <div className="m-2">
      <div className="mb-2 preview-text truncate">{props.previewText}</div>

      {label}

      <div className="ml-3">
        {props.objectives.map(o => <div className="truncate rbt-token" key={o}>{o}</div>)}
      </div>

    </div>
  );
};
