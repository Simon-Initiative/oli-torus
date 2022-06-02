import React from 'react';

export interface SurveyControlsProps {
  id: string;
}

export const SurveyControls = ({ id }: SurveyControlsProps) => {
  const onSubmit = () => console.log('Submit Survey ' + id);

  return (
    <div className="d-flex">
      <div className="flex-grow-1"></div>
      <button className="btn btn-primary" onClick={onSubmit}>
        Submit Survey
      </button>
      <div className="flex-grow-1"></div>
    </div>
  );
};
