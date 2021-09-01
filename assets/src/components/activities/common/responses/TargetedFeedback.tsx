import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { getTargetedResponseMappings, ResponseMapping } from 'data/activities/model/responseUtils';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import {
  ChoiceId,
  ChoiceIdsToResponseId,
  HasChoices,
  HasParts,
  RichText,
} from 'components/activities/types';
import { defaultWriterContext } from 'data/content/writers/context';
import React from 'react';

interface Props {
  toggleChoice: (id: ChoiceId, mapping: ResponseMapping) => void;
  addTargetedResponse: () => void;
  selectedIcon: React.ReactNode;
  unselectedIcon: React.ReactNode;
  children?: React.ReactNode | ((xs: ReturnType<typeof useTargetedFeedback>) => React.ReactNode);
}

export const useTargetedFeedback = () => {
  const { model, dispatch } = useAuthoringElementContext<
    HasParts & { authoring: { targeted: ChoiceIdsToResponseId[] } }
  >();

  return {
    targetedMappings: getTargetedResponseMappings(model),
    updateFeedback: (responseId: string, content: RichText) =>
      dispatch(ResponseActions.editResponseFeedback(responseId, content)),
    removeFeedback: (responseId: string) =>
      dispatch(ResponseActions.removeTargetedFeedback(responseId)),
  };
};

export const TargetedFeedback: React.FC<Props> = (props) => {
  const hook = useTargetedFeedback();

  return (
    <>
      {hook.targetedMappings.map((mapping) => (
        <ResponseCard
          key={mapping.response.id}
          title="Targeted feedback"
          response={mapping.response}
          updateFeedback={hook.updateFeedback}
          removeResponse={hook.removeFeedback}
        >
          {typeof props.children === 'function' ? props.children(hook) : props.children}
          {/* <ChoicesDelivery
            unselectedIcon={unselectedIcon}
            selectedIcon={selectedIcon}
            choices={choices}
            selected={mapping.choiceIds}
            onSelect={(id) => toggleChoice(id, mapping)}
            isEvaluated={false}
            context={defaultWriterContext()}
          /> */}
        </ResponseCard>
      ))}
      <AuthoringButtonConnected className="btn btn-link pl-0" action={props.addTargetedResponse}>
        Add targeted feedback
      </AuthoringButtonConnected>
    </>
  );
};
