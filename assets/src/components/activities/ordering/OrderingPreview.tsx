import React from 'react';
import { usePreviewElementContext } from 'components/activities/PreviewElementProvider';
import { ActivityPreviewCard } from 'components/activities/common/preview/ActivityPreviewCard';
import { PreviewOrderedChoiceList } from 'components/activities/common/preview/PreviewOrderedChoiceList';
import { PreviewQuestionStem } from 'components/activities/common/preview/PreviewQuestionStem';
import { standardDetailTabs } from 'components/activities/common/preview/StandardDetailTabs';
import {
  choicesInIdOrder,
  correctChoiceIdsForModel,
} from 'components/activities/common/preview/previewUtils';
import { ResponseMapping } from 'data/activities/model/responses';
import { OrderingSchema } from './schema';

export const OrderingPreview: React.FC = () => {
  const { model, previewContext } = usePreviewElementContext<OrderingSchema>();
  const partId = model.authoring.parts[0].id;
  const correctChoices = choicesInIdOrder(model.choices, correctChoiceIdsForModel(model));

  const detailTabs = standardDetailTabs({
    model,
    partId,
    answerKeyChoices: model.choices,
    answerKeySummary: <PreviewOrderedChoiceList choices={correctChoices} />,
    targetedResponseChoicesRenderer: (mapping: ResponseMapping, choices) => (
      <PreviewOrderedChoiceList choices={choicesInIdOrder(choices, mapping.choiceIds)} />
    ),
  });

  return (
    <ActivityPreviewCard previewContext={previewContext} detailTabs={detailTabs}>
      <div className="flex flex-col gap-4">
        <PreviewQuestionStem model={model} />
        <PreviewOrderedChoiceList choices={model.choices} />
      </div>
    </ActivityPreviewCard>
  );
};
