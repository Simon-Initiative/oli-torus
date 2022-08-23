import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { Actions } from 'components/activities/ordering/actions';
import { OrderingSchema } from 'components/activities/ordering/schema';
import { ResponseChoices } from 'components/activities/ordering/sections/ResponseChoices';
import { RichText } from 'components/activities/types';
import { Choices } from 'data/activities/model/choices';
import { getTargetedResponseMappings } from 'data/activities/model/responses';
import { ShowPage } from 'components/activities/common/responses/ShowPage';
import React from 'react';

export const TargetedFeedback: React.FC = () => {
  const { model, dispatch, authoringContext, editMode } =
    useAuthoringElementContext<OrderingSchema>();
  return (
    <>
      {getTargetedResponseMappings(model).map((mapping) => (
        <ResponseCard
          title="Targeted feedback"
          response={mapping.response}
          updateFeedback={(id, content) =>
            dispatch(ResponseActions.editResponseFeedback(mapping.response.id, content as RichText))
          }
          removeResponse={(id) => dispatch(ResponseActions.removeTargetedFeedback(id))}
          key={mapping.response.id}
        >
          <ResponseChoices
            choices={mapping.choiceIds.map((id) => Choices.getOne(model, id))}
            setChoices={(choices) =>
              dispatch(
                Actions.editTargetedFeedbackChoices(
                  mapping.response.id,
                  choices.map((c) => c.id),
                ),
              )
            }
          />
          {authoringContext.contentBreaksExist ? (
            <ShowPage
              editMode={editMode}
              index={mapping.response.showPage}
              onChange={(showPage: any) =>
                dispatch(ResponseActions.editShowPage(mapping.response.id, showPage))
              }
            />
          ) : null}
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
