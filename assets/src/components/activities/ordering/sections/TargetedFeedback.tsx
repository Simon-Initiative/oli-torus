import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { getChoice } from 'components/activities/common/choices/authoring/choiceUtils';
import { getTargetedResponseMappings } from 'components/activities/common/responses/authoring/responseUtils';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { Actions } from 'components/activities/ordering/actions';
import { OrderingSchema } from 'components/activities/ordering/schema';
import { ResponseChoices } from 'components/activities/ordering/sections/ResponseChoices';
import React from 'react';

export const TargetedFeedback: React.FC = () => {
  const { model, dispatch } = useAuthoringElementContext<OrderingSchema>();
  return (
    <>
      {getTargetedResponseMappings(model).map((mapping) => (
        <ResponseCard
          title="Targeted feedback"
          response={mapping.response}
          updateFeedback={(id, content) =>
            dispatch(ResponseActions.editResponseFeedback(mapping.response.id, content))
          }
          onRemove={(id) => dispatch(ResponseActions.removeTargetedFeedback(id))}
          key={mapping.response.id}
        >
          <ResponseChoices
            choices={mapping.choiceIds.map((id) => getChoice(model, id))}
            setChoices={(choices) =>
              dispatch(
                Actions.editTargetedFeedbackChoices(
                  mapping.response.id,
                  choices.map((c) => c.id),
                ),
              )
            }
          />
        </ResponseCard>
      ))}
      <AuthoringButtonConnected
        className="align-self-start btn btn-link"
        action={() => dispatch(Actions.addTargetedFeedback())}
      >
        Add targeted feedback
      </AuthoringButtonConnected>
    </>
  );
};
