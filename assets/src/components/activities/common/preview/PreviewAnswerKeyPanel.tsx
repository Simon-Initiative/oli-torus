import React from 'react';
import { Choice, Response } from 'components/activities/types';
import { ResponseMapping } from 'data/activities/model/responses';
import { PreviewResponsePanel, PreviewTargetedResponses } from './PreviewResponsePanels';

interface Props {
  summary: React.ReactNode;
  correctResponse?: Response | null;
  incorrectResponse?: Response | null;
  targetedResponses?: Response[];
  targetedResponseMappings?: ResponseMapping[];
  answerKeyChoices?: Choice[];
  answerKeyMultiSelect?: boolean;
}

export const PreviewAnswerKeyPanel: React.FC<Props> = ({
  summary,
  correctResponse,
  incorrectResponse,
  targetedResponses = [],
  targetedResponseMappings = [],
  answerKeyChoices = [],
  answerKeyMultiSelect = false,
}) => {
  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-3">{summary}</div>

      <PreviewResponsePanel
        response={correctResponse}
        title="Feedback for correct answer:"
      />
      <PreviewResponsePanel
        response={incorrectResponse}
        title="Feedback for incorrect answer:"
      />
      <PreviewTargetedResponses
        responses={targetedResponses}
        responseMappings={targetedResponseMappings}
        choices={answerKeyChoices}
        multiSelect={answerKeyMultiSelect}
      />
    </div>
  );
};
