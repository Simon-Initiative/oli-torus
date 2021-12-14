import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { Actions } from 'components/activities/ordering/actions';
import { ResponseChoices } from 'components/activities/ordering/sections/ResponseChoices';
import { Choices } from 'data/activities/model/choices';
import { getTargetedResponseMappings } from 'data/activities/model/responses';
import React from 'react';
export const TargetedFeedback = () => {
    const { model, dispatch } = useAuthoringElementContext();
    return (<>
      {getTargetedResponseMappings(model).map((mapping) => (<ResponseCard title="Targeted feedback" response={mapping.response} updateFeedback={(id, content) => dispatch(ResponseActions.editResponseFeedback(mapping.response.id, content))} removeResponse={(id) => dispatch(ResponseActions.removeTargetedFeedback(id))} key={mapping.response.id}>
          <ResponseChoices choices={mapping.choiceIds.map((id) => Choices.getOne(model, id))} setChoices={(choices) => dispatch(Actions.editTargetedFeedbackChoices(mapping.response.id, choices.map((c) => c.id)))}/>
        </ResponseCard>))}
      <AuthoringButtonConnected className="align-self-start btn btn-link" action={() => dispatch(Actions.addTargetedFeedback())}>
        Add targeted feedback
      </AuthoringButtonConnected>
    </>);
};
//# sourceMappingURL=TargetedFeedback.jsx.map