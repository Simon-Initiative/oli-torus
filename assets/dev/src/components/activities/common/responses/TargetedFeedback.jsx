import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { getTargetedResponseMappings } from 'data/activities/model/responses';
import { defaultWriterContext } from 'data/content/writers/context';
import React from 'react';
export const useTargetedFeedback = () => {
    const { model, dispatch } = useAuthoringElementContext();
    return {
        targetedMappings: getTargetedResponseMappings(model),
        updateFeedback: (responseId, content) => dispatch(ResponseActions.editResponseFeedback(responseId, content)),
        removeFeedback: (responseId) => dispatch(ResponseActions.removeTargetedFeedback(responseId)),
    };
};
export const TargetedFeedback = (props) => {
    const hook = useTargetedFeedback();
    const { model } = useAuthoringElementContext();
    if (typeof props.children === 'function') {
        return props.children(hook);
    }
    return (<>
      {hook.targetedMappings.map((mapping) => (<ResponseCard key={mapping.response.id} title="Targeted feedback" response={mapping.response} updateFeedback={hook.updateFeedback} removeResponse={hook.removeFeedback}>
          <ChoicesDelivery unselectedIcon={props.unselectedIcon} selectedIcon={props.selectedIcon} choices={props.choices || model.choices} selected={mapping.choiceIds} onSelect={(id) => props.toggleChoice(id, mapping)} isEvaluated={false} context={defaultWriterContext()}/>
        </ResponseCard>))}
      <AuthoringButtonConnected className="btn btn-link pl-0" action={props.addTargetedResponse}>
        Add targeted feedback
      </AuthoringButtonConnected>
    </>);
};
//# sourceMappingURL=TargetedFeedback.jsx.map