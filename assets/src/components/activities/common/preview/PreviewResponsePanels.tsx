import React from 'react';
import { Choice, Response } from 'components/activities/types';
import { ResponseMapping } from 'data/activities/model/responses';
import { PreviewChoiceList } from './PreviewChoiceList';
import { PreviewPanel } from './PreviewPanel';
import { PreviewRichText } from './PreviewRichText';

interface ResponsePanelProps {
  response?: Response | null;
  title: string;
}

export const PreviewResponsePanel: React.FC<ResponsePanelProps> = ({ response, title }) => {
  if (!response) {
    return null;
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="text-base font-normal leading-6 text-Text-text-high">{title}</div>
      <PreviewPanel tone="feedback">
        <PreviewRichText
          content={response.feedback.content}
          direction={response.feedback.textDirection || 'auto'}
        />
      </PreviewPanel>
    </div>
  );
};

interface TargetedResponsesProps {
  responses: Response[];
  responseMappings?: ResponseMapping[];
  choices?: Choice[];
  multiSelect?: boolean;
  renderChoices?: (
    mapping: ResponseMapping,
    choices: Choice[],
    multiSelect: boolean,
  ) => React.ReactNode;
}

export const PreviewTargetedResponses: React.FC<TargetedResponsesProps> = ({
  responses,
  responseMappings = [],
  choices = [],
  multiSelect = false,
  renderChoices,
}) => {
  if (responses.length === 0) {
    return null;
  }

  return (
    <div className="flex flex-col gap-4">
      {responses.map((response, index) => (
        <div
          key={response.id}
          className="flex flex-col gap-[9px] rounded-[3px] border border-Border-border-default px-4 py-3"
        >
          <div className="text-base font-normal text-Text-text-high">Targeted feedback:</div>
          <div className="rounded-md border border-Border-border-default bg-Specially-Tokens-Fill-fill-input-focused px-4 py-2">
            <PreviewRichText
              content={response.feedback.content}
              direction={response.feedback.textDirection || 'auto'}
              className="text-base leading-6 text-Text-text-high [&_.content_p]:my-0"
            />
          </div>
          {responseMappings.length > 0 && choices.length > 0
            ? (() => {
                const mapping = responseMappings.find(
                  (candidate) => candidate.response.id === response.id,
                );
                if (!mapping) {
                  return null;
                }

                return renderChoices ? (
                  renderChoices(mapping, choices, multiSelect)
                ) : (
                  <PreviewChoiceList
                    choices={choices}
                    selectedChoiceIds={mapping.choiceIds}
                    multiSelect={multiSelect}
                    surface="plain"
                  />
                );
              })()
            : null}
        </div>
      ))}
    </div>
  );
};
