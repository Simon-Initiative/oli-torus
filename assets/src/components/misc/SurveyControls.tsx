import React, { useState } from 'react';
import * as Events from 'data/events';

export interface SurveyControlsProps {
  id: string;
  isSubmitted: boolean;
}

export const SurveyControls = ({ id, isSubmitted }: SurveyControlsProps) => {
  const [submitted, setSubmitted] = useState(isSubmitted);
  const onSubmit = () => {
    Events.dispatch(Events.Registry.SurveySubmit, Events.makeSurveySubmitEvent({ id }));
    setSubmitted(true);
  };
  const onReset = () => {
    Events.dispatch(Events.Registry.SurveyReset, Events.makeSurveyResetEvent({ id }));
    setSubmitted(false);
  };

  return submitted ? (
    <SubmittedMessage onReset={onReset} />
  ) : (
    <SubmitSurveyButton onSubmit={onSubmit} />
  );
};

type SubmitSurveyButtonProps = {
  onSubmit: () => void;
};

const SubmitSurveyButton = ({ onSubmit }: SubmitSurveyButtonProps) => (
  <div className="d-flex mb-4">
    <div className="flex-grow-1"></div>
    <button className="btn btn-primary" onClick={onSubmit}>
      Submit Survey
    </button>
    <div className="flex-grow-1"></div>
  </div>
);

type SubmittedMessageProps = {
  onReset: () => void;
};

const SubmittedMessage = ({ onReset }: SubmittedMessageProps) => (
  <div className="m-4">
    <div className="alert alert-info d-flex">
      <div className="py-1">Your response has been submitted.</div>
      <div className="flex-grow-1"></div>
      <button className="btn btn-link btn-sm" onClick={onReset}>
        Reset
      </button>
    </div>
  </div>
);
