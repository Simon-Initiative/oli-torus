import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { ShowPage } from './ShowPage';
import {
  Choice,
  ChoiceId,
  ChoiceIdsToResponseId,
  HasChoices,
  HasParts,
  RichText,
} from 'components/activities/types';
import { getTargetedResponseMappings, ResponseMapping } from 'data/activities/model/responses';
import { defaultWriterContext } from 'data/content/writers/context';
import React from 'react';

interface Props {
  choices?: Choice[];
  toggleChoice: (id: ChoiceId, mapping: ResponseMapping) => void;
  addTargetedResponse: () => void;
  selectedIcon: React.ReactNode;
  unselectedIcon: React.ReactNode;
  children?: (xs: ReturnType<typeof useTargetedFeedback>) => React.ReactElement;
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
    updateShowPage: (responseId: string, showPage: number | undefined) =>
      dispatch(ResponseActions.editShowPage(responseId, showPage)),
  };
};

// get subset of response mappings for given choice set only, for use w/multipart items
export const getFeedbackForChoices = (
  partChoices: Choice[],
  allTargetedMappings: ResponseMapping[],
): ResponseMapping[] => {
  const partChoiceIds = partChoices.map((choice) => choice.id);
  return allTargetedMappings.filter((assoc) =>
    assoc.choiceIds.every((id) => partChoiceIds.includes(id)),
  );
};

export const TargetedFeedback: React.FC<Props> = (props) => {
  const hook = useTargetedFeedback();
  const { model, authoringContext, editMode, projectSlug } = useAuthoringElementContext<
    HasParts & HasChoices & { authoring: { targeted: ChoiceIdsToResponseId[] } }
  >();
  const writerContext = defaultWriterContext({
    projectSlug: projectSlug,
  });

  if (typeof props.children === 'function') {
    return props.children(hook);
  }

  // only show feedbacks for relevant choice set, presumably current part's on multipart
  const partMappings = getFeedbackForChoices(props.choices || model.choices, hook.targetedMappings);
  return (
    <>
      {partMappings.map((mapping) => (
        <ResponseCard
          key={mapping.response.id}
          title="Targeted feedback"
          response={mapping.response}
          updateFeedback={hook.updateFeedback}
          removeResponse={hook.removeFeedback}
        >
          <ChoicesDelivery
            unselectedIcon={props.unselectedIcon}
            selectedIcon={props.selectedIcon}
            choices={props.choices || model.choices}
            selected={mapping.choiceIds}
            onSelect={(id) => props.toggleChoice(id, mapping)}
            isEvaluated={false}
            context={writerContext}
          />
          {authoringContext.contentBreaksExist ? (
            <ShowPage
              editMode={editMode}
              index={mapping.response.showPage}
              onChange={(v) => hook.updateShowPage(mapping.response.id, v)}
            />
          ) : null}
        </ResponseCard>
      ))}
      <AuthoringButtonConnected className="btn btn-link pl-0" action={props.addTargetedResponse}>
        Add targeted feedback
      </AuthoringButtonConnected>
    </>
  );
};
