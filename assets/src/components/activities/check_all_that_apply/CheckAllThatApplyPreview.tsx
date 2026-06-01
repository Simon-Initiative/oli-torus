import React from 'react';
import { usePreviewElementContext } from 'components/activities/PreviewElementProvider';
import { ActivityPreviewCard } from 'components/activities/common/preview/ActivityPreviewCard';
import { PreviewChoiceList } from 'components/activities/common/preview/PreviewChoiceList';
import { PreviewQuestionStem } from 'components/activities/common/preview/PreviewQuestionStem';
import { standardDetailTabs } from 'components/activities/common/preview/StandardDetailTabs';
import { correctChoiceIdsForModel } from 'components/activities/common/preview/previewUtils';
import { CATASchema } from './schema';

export const CheckAllThatApplyPreview: React.FC = () => {
  const { model, previewContext } = usePreviewElementContext<CATASchema>();
  const partId = model.authoring.parts[0].id;
  const correctChoiceIds = correctChoiceIdsForModel(model);

  const detailTabs = standardDetailTabs({
    model,
    partId,
    answerKeyChoices: model.choices,
    answerKeyMultiSelect: true,
    answerKeySummary: (
      <PreviewChoiceList
        choices={model.choices}
        selectedChoiceIds={correctChoiceIds}
        multiSelect
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
          multiSelect
          surface="card"
        />
      </div>
    </ActivityPreviewCard>
  );
};
