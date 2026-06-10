import React from 'react';
import { Choice, ChoiceIdsToResponseId, HasParts } from 'components/activities/types';
import { getTargetedResponseMappings } from 'data/activities/model/responses';
import { PreviewAnswerKeyPanel } from './PreviewAnswerKeyPanel';
import { PreviewExplanationPanel } from './PreviewExplanationPanel';
import { PreviewHintsPanel } from './PreviewHintsPanel';
import { standardFeedbackData } from './previewUtils';
import { PreviewTab } from './types';

interface Props {
  model: HasParts;
  partId: string;
  answerKeySummary: React.ReactNode;
  answerKeyChoices?: Choice[];
  answerKeyMultiSelect?: boolean;
  targetedResponseChoicesRenderer?: (
    mapping: ReturnType<typeof getTargetedResponseMappings>[number],
    choices: Choice[],
    multiSelect: boolean,
  ) => React.ReactNode;
}

export const standardDetailTabs = ({
  model,
  partId,
  answerKeySummary,
  answerKeyChoices = [],
  answerKeyMultiSelect = false,
  targetedResponseChoicesRenderer,
}: Props): PreviewTab[] => {
  const part = model.authoring.parts.find((candidate) => candidate.id === partId);
  const targeted = (model.authoring as { targeted?: ChoiceIdsToResponseId[] } | undefined)
    ?.targeted;
  const targetedResponseMappings = Array.isArray(targeted)
    ? getTargetedResponseMappings(
        model as HasParts & {
          authoring: { targeted: ChoiceIdsToResponseId[] };
        },
      )
    : [];

  return [
    {
      id: 'answer-key',
      label: 'Answer Key',
      content: (
        <PreviewAnswerKeyPanel
          summary={answerKeySummary}
          {...standardFeedbackData(model, partId, targetedResponseMappings)}
          targetedResponseMappings={targetedResponseMappings}
          answerKeyChoices={answerKeyChoices}
          answerKeyMultiSelect={answerKeyMultiSelect}
          targetedResponseChoicesRenderer={targetedResponseChoicesRenderer}
        />
      ),
    },
    {
      id: 'hints',
      label: 'Hints',
      content: <PreviewHintsPanel hints={part?.hints || []} />,
    },
    {
      id: 'explanation',
      label: 'Explanation',
      content: <PreviewExplanationPanel model={model} partId={partId} />,
    },
  ];
};
