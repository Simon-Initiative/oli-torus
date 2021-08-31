import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { getTargetedResponseMappings, ResponseMapping } from 'data/activities/model/responseUtils';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { ChoiceId, ChoiceIdsToResponseId, HasChoices, HasParts } from 'components/activities/types';
import { defaultWriterContext } from 'data/content/writers/context';
import React from 'react';

interface Props {
  toggleChoice: (id: ChoiceId, mapping: ResponseMapping) => void;
  addTargetedResponse: () => void;
  selectedIcon: React.ReactNode;
  unselectedIcon: React.ReactNode;
}

export const useTargetedFeedback = () => {
  const { model, dispatch } = useAuthoringElementContext<
    HasChoices & HasParts & { authoring: { targeted: ChoiceIdsToResponseId[] } }
  >();
  const choices = model.choices;

  return {
    targetedMappings: getTargetedResponseMappings(model),
    updateFeedback: (id, content) =>
      dispatch(ResponseActions.editResponseFeedback(mapping.response.id, content)),
    removeTargetedFeedback: (id) => dispatch(ResponseActions.removeTargetedFeedback(id)),
  };
};

export const TargetedFeedback: React.FC<Props> = ({
  toggleChoice,
  addTargetedResponse,
  selectedIcon,
  unselectedIcon,
}) => {
  return (
    <>
      {targetedMappings.map((mapping) => (
        <ResponseCard
          key={mapping.response.id}
          title="Targeted feedback"
          response={mapping.response}
          updateFeedback={(id, content) =>
            dispatch(ResponseActions.editResponseFeedback(mapping.response.id, content))
          }
          onRemove={(id) => dispatch(ResponseActions.removeTargetedFeedback(id))}
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
