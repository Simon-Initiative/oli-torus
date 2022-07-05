import React, { useState } from 'react';

export interface SurveyControlsProps {
  id: string;
  isSubmitted: boolean;
}

export interface SurveyEventDetails {
  id: string;
}

export const SurveyControls = ({ id, isSubmitted }: SurveyControlsProps) => {
  const [submitted, setSubmitted] = useState(isSubmitted);
  const onSubmit = () => {
    document.dispatchEvent(
      new CustomEvent<SurveyEventDetails>('oli-survey-submit', { detail: { id } }),
    );
    setSubmitted(true);
  };
  const onReset = () => {
    document.dispatchEvent(
      new CustomEvent<SurveyEventDetails>('oli-survey-reset', { detail: { id } }),
    );
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
