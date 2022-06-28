import React from 'react';

export interface SurveyControlsProps {
  id: string;
}

export interface SubmitSurveyEventDetails {
  id: string;
}

export const SurveyControls = ({ id }: SurveyControlsProps) => {
  const onSubmit = () =>
    document.dispatchEvent(
      new CustomEvent<SubmitSurveyEventDetails>('oli-survey-submit', { detail: { id } }),
    );

  return (
    <div className="d-flex mb-4">
      <div className="flex-grow-1"></div>
      <button className="btn btn-primary" onClick={onSubmit}>
        Submit Survey
      </button>
      <div className="flex-grow-1"></div>
    </div>
  );
};
