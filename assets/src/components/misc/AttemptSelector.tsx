import React, { useState } from 'react';
import { Dropdown } from 'react-bootstrap';
import * as Events from 'data/events';
import { makeRequest } from 'data/persistence/common';

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
      <Dropdown.Item
        key={a.attemptGuid}
        onClick={() => {
          fetchAttempt(activityId, sectionSlug, a.attemptGuid);
          setCurrent(a);
        }}
        className="bg-Fill-Buttons-fill-primary"
      >
        Attempt #{a.attemptNumber}: [{a.state}] {a.date}
      </Dropdown.Item>
    );
  });

  if (choices.length > 1) {
    choices.splice(0, 0, <Dropdown.Header key="previous">Previous attempts</Dropdown.Header>);
  }
  choices.splice(
    choices.length - 1,
    0,
    <Dropdown.Header key="recent">Most recent attempt</Dropdown.Header>,
  );

  return (
    <Dropdown className="btn-group">
      <Dropdown.Toggle className="bg-Fill-Buttons-fill-primary">
        Attempt #{current.attemptNumber}: [{current.state}] {current.date}
      </Dropdown.Toggle>
      <Dropdown.Menu className="dropdown-menu">{choices}</Dropdown.Menu>
    </Dropdown>
  );
};
