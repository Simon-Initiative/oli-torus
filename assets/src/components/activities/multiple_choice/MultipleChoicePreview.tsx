import React from 'react';
import { usePreviewElementContext } from 'components/activities/PreviewElementProvider';
import { ActivityPreviewCard } from 'components/activities/common/preview/ActivityPreviewCard';
import { PreviewChoiceList } from 'components/activities/common/preview/PreviewChoiceList';
import { PreviewQuestionStem } from 'components/activities/common/preview/PreviewQuestionStem';
import { standardDetailTabs } from 'components/activities/common/preview/StandardDetailTabs';
import { MCSchema } from './schema';
import { getCorrectChoice } from './utils';

export const MultipleChoicePreview: React.FC = () => {
  const { model, previewContext } = usePreviewElementContext<MCSchema>();
  const partId = model.authoring.parts[0].id;
  const correctChoice = getCorrectChoice(model, partId).caseOf({
    just: (choice) => choice,
    nothing: () => model.choices[0],
  });

  const detailTabs = standardDetailTabs({
    model,
    partId,
    answerKeyChoices: model.choices,
    answerKeySummary: (
      <PreviewChoiceList
        choices={model.choices}
        selectedChoiceIds={[correctChoice.id]}
        surface="plain"
      />
    ),
  });

  return (
    <ActivityPreviewCard previewContext={previewContext} detailTabs={detailTabs}>
      <div className="flex flex-col gap-4">
        <PreviewQuestionStem model={model} />
        <PreviewChoiceList
          choices={model.choices}
          selectedChoiceIds={[]}
          showSelectionControl={false}
          surface="card"
        />
      </div>
    </ActivityPreviewCard>
  );
};
