import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import {
  Choice,
  ChoiceId,
  ChoiceIdsToResponseId,
  HasChoices,
  HasParts,
  RichText,
} from 'components/activities/types';
import {
  ResponseMapping,
  getCorrectResponse,
  getTargetedResponseMappings,
  hasCustomScoring,
} from 'data/activities/model/responses';
import { TextDirection } from 'data/content/model/elements/types';
import { EditorType } from 'data/content/resource';
import { defaultWriterContext } from 'data/content/writers/context';
import { ShowPage } from './ShowPage';

interface Props {
  choices?: Choice[];
  partId?: string;
  toggleChoice: (id: ChoiceId, mapping: ResponseMapping) => void;
  addTargetedResponse: () => void;
  selectedIcon: React.ReactNode;
  unselectedIcon: React.ReactNode;
  disabled?: boolean;
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
    updateFeedbackTextDirection: (responseId: string, textDirection: TextDirection) =>
      dispatch(ResponseActions.editResponseFeedbackTextDirection(responseId, textDirection)),
    updateFeedbackEditor: (responseId: string, editor: EditorType) =>
      dispatch(ResponseActions.editResponseFeedbackEditor(responseId, editor)),
    updateCorrectness: (responseId: string, correct: boolean) =>
      dispatch(ResponseActions.editResponseCorrectness(responseId, correct)),
    removeFeedback: (responseId: string) =>
      dispatch(ResponseActions.removeTargetedFeedback(responseId)),
    updateShowPage: (responseId: string, showPage: number | undefined) =>
      dispatch(ResponseActions.editShowPage(responseId, showPage)),
    updateScore: (responseId: string, score: number) =>
      dispatch(ResponseActions.editResponseScore(responseId, score)),
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
  const { model, authoringContext, editMode, mode, projectSlug } = useAuthoringElementContext<
    HasParts & HasChoices & { authoring: { targeted: ChoiceIdsToResponseId[] } }
  >();
  const writerContext = defaultWriterContext({
    projectSlug: projectSlug,
  });
  const isInstructorPreview = mode === 'instructor_preview';
  const responseEditMode = editMode && !isInstructorPreview;

  if (typeof props.children === 'function') {
    return props.children(hook);
  }

  // only show feedbacks for relevant choice set, presumably current part's on multipart
  const partMappings = getFeedbackForChoices(props.choices || model.choices, hook.targetedMappings);
  // some migrated qs erroneously included correct answer in targeted feedback map: ignore
  const correctResponse = getCorrectResponse(model, props.partId || model.authoring.parts[0].id);
  const mappings = partMappings.filter((m) => m.response !== correctResponse);

  const customScoring = hasCustomScoring(model);

  return (
    <>
      {mappings.map((mapping) => (
        <ResponseCard
          key={mapping.response.id}
          title="Targeted feedback"
          response={mapping.response}
          updateFeedback={hook.updateFeedback}
          updateFeedbackEditor={hook.updateFeedbackEditor}
          updateCorrectness={hook.updateCorrectness}
          updateScore={hook.updateScore}
          removeResponse={hook.removeFeedback}
          updateFeedbackTextDirection={hook.updateFeedbackTextDirection}
          customScoring={customScoring}
          editMode={responseEditMode}
        >
          <ChoicesDelivery
            unselectedIcon={props.unselectedIcon}
            selectedIcon={props.selectedIcon}
            choices={props.choices || model.choices}
            selected={mapping.choiceIds}
            onSelect={(id) => props.toggleChoice(id, mapping)}
            isEvaluated={false}
            context={writerContext}
            disabled={props.disabled}
          />

          {authoringContext.contentBreaksExist ? (
            <ShowPage
              editMode={responseEditMode}
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
