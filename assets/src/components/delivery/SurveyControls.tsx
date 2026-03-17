import React, { useState } from 'react';
import * as Events from 'data/events';

export interface SurveyControlsProps {
  id: string;
  isSubmitted: boolean;
  canReset?: boolean;
}

export const SurveyControls = ({ id, isSubmitted, canReset = false }: SurveyControlsProps) => {
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
    <SubmittedMessage onReset={onReset} canReset={canReset} />
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
    <button
      className="px-3 py-2 rounded-sm cursor-pointer text-white self-start mt-3 mb-3 bg-Fill-Buttons-fill-primary hover:bg-Fill-Buttons-fill-primary-hover disabled:text-Text-text-low disabled:bg-Fill-Chip-Gray disabled:cursor-not-allowed"
      onClick={onSubmit}
    >
      Submit Survey
    </button>
    <div className="flex-grow-1"></div>
  </div>
);

type SubmittedMessageProps = {
  onReset: () => void;
  canReset: boolean;
};

const SubmittedMessage = ({ onReset, canReset }: SubmittedMessageProps) => (
  <div className="m-4">
    <div className="alert alert-info d-flex">
      <div className="py-1">Your response has been submitted.</div>
      <div className="flex-grow-1"></div>
      {canReset ? (
        <button className="btn btn-link btn-sm" onClick={onReset}>
          Reset
        </button>
      ) : null}
    </div>
  </div>
);
