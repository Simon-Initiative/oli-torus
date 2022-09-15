import React, { useState } from 'react';
import { makeRequest } from 'data/persistence/common';
import * as Events from 'data/events';

export interface AttemptDetails {
  attemptNumber: number;
  attemptGuid: string;
  date: string;
  state: 'active' | 'evaluated' | 'submitted';
}

export interface AttemptSelectorProps {
  sectionSlug: string;
  attempts: AttemptDetails[];
  activityId: number;
}

type FetchAttemptResult = {
  result: 'success';
  model: Record<string, unknown>;
  state: Record<string, unknown>;
};

function fetchAttempt(activityId: number, sectionSlug: string, attemptGuid: string) {
  const params = {
    url: `/state/course/${sectionSlug}/activity_attempt/${attemptGuid}/`,
    method: 'GET',
  };
  makeRequest<FetchAttemptResult>(params).then((result) => {
    if (result.result === 'success') {
      Events.dispatch(
        Events.Registry.ReviewModeAttemptChange,
        Events.makeReviewModeAttemptChange({
          forId: activityId,
          model: result.model,
          state: result.state,
        }),
      );
    }
  });
}

export const AttemptSelector = (props: AttemptSelectorProps) => {
  const { attempts, sectionSlug, activityId } = props;
  const [current, setCurrent] = useState(attempts[attempts.length - 1]);

  const choices = attempts.map((a: AttemptDetails) => {
    return (
      <a
        key={a.attemptGuid}
        className="dropdown-item"
        href="#"
        onClick={() => {
          fetchAttempt(activityId, sectionSlug, a.attemptGuid);
          setCurrent(a);
        }}
      >
        Attempt #{a.attemptNumber}: [{a.state}] {a.date}
      </a>
    );
  });

  if (choices.length > 1) {
    choices.splice(
      0,
      0,
      <h6 key="previous" className="dropdown-header">
        Previous attempts
      </h6>,
    );
  }
  choices.splice(
    choices.length - 1,
    0,
    <h6 key="recent" className="dropdown-header">
      Most recent attempt
    </h6>,
  );

  return (
    <div className="btn-group">
      <button
        type="button"
        className="btn btn-info dropdown-toggle"
        data-toggle="dropdown"
        aria-expanded="false"
      >
        Attempt #{current.attemptNumber}: [{current.state}] {current.date}
      </button>
      <div className="dropdown-menu">{choices}</div>
    </div>
  );
};
