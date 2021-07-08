import { ResponseMapping } from 'components/activities/check_all_that_apply/utils';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { Choice, ChoiceId, RichText } from 'components/activities/types';
import { ID } from 'data/content/model';
import { defaultWriterContext } from 'data/content/writers/context';
import React from 'react';

interface Props {
  choices: Choice[];
  targetedMappings: ResponseMapping[];
  toggleChoice: (id: ChoiceId, mapping: ResponseMapping) => void;
  updateResponse: (id: ID, content: RichText) => void;
  addTargetedResponse: () => void;
  selectedIcon: React.ReactNode;
  unselectedIcon: React.ReactNode;
  onRemove: (responseId: ID) => void;
}
export const TargetedFeedback: React.FC<Props> = ({
  choices,
  targetedMappings,
  toggleChoice,
  updateResponse,
  addTargetedResponse,
  selectedIcon,
  unselectedIcon,
  onRemove,
}) => {
  return (
    <>
      {targetedMappings.map((mapping) => (
        <ResponseCard
          key={mapping.response.id}
          title="Targeted feedback"
          response={mapping.response}
          updateFeedback={(id, content) => updateResponse(mapping.response.id, content)}
          onRemove={onRemove}
        >
          <ChoicesDelivery
            unselectedIcon={unselectedIcon}
            selectedIcon={selectedIcon}
            choices={choices}
            selected={mapping.choiceIds}
            onSelect={(id) => toggleChoice(id, mapping)}
            isEvaluated={false}
            context={defaultWriterContext()}
          />
        </ResponseCard>
      ))}
      <AuthoringButtonConnected className="btn btn-link pl-0" action={addTargetedResponse}>
        Add targeted feedback
      </AuthoringButtonConnected>
    </>
  );
};
