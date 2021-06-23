import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
} from '../AuthoringElement';
import { CheckAllThatApplyModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Feedback } from './sections/Feedback';
import { Actions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import produce from 'immer';
import { TargetedFeedback } from 'components/activities/check_all_that_apply/sections/TargetedFeedback';
import { getHints, isTargetedCATA } from 'components/activities/check_all_that_apply/utils';
import { StemAuthoring } from 'components/activities/common/stem/StemAuthoring';
import { ChoicesAuthoringConnected } from 'components/activities/common/choices/ChoicesAuthoring';
import { Checkbox } from 'components/activities/common/icons/Checkbox';
import { HintsAuthoring } from 'components/activities/common/hints/HintsAuthoring';

const store = configureStore();

const CheckAllThatApply = (props: AuthoringElementProps<CheckAllThatApplyModelSchema>) => {
  const dispatch = (action: any) =>
    props.onEdit(produce(props.model, (draftState) => action(draftState)));

  const sharedProps = {
    model: props.model,
    editMode: props.editMode,
    projectSlug: props.projectSlug,
  };

  return (
    <React.Fragment>
      <StemAuthoring
        {...sharedProps}
        stem={props.model.stem}
        onEdit={(content) => dispatch(Actions.editStem(content))}
      />

      <ChoicesAuthoringConnected
        icon={<Checkbox.Unchecked />}
        choices={props.model.choices}
        addOne={() => dispatch(Actions.addChoice())}
        setAll={(choices: ActivityTypes.Choice[]) => dispatch(Actions.setAllChoices(choices))}
        onEdit={(id, content) => dispatch(Actions.editChoiceContent(id, content))}
        onRemove={(id) => dispatch(Actions.removeChoice(id))}
      />
      <Feedback
        {...sharedProps}
        onToggleFeedbackMode={() => dispatch(Actions.toggleType())}
        onEditResponseFeedback={(responseId, feedbackContent) =>
          dispatch(Actions.editResponseFeedback(responseId, feedbackContent))
        }
      >
        {isTargetedCATA(props.model) && (
          <TargetedFeedback
            {...sharedProps}
            model={props.model}
            onEditResponseFeedback={(responseId, feedbackContent) =>
              dispatch(Actions.editResponseFeedback(responseId, feedbackContent))
            }
            onAddTargetedFeedback={() => dispatch(Actions.addTargetedFeedback())}
            onRemoveTargetedFeedback={(responseId: ActivityTypes.ResponseId) =>
              dispatch(Actions.removeTargetedFeedback(responseId))
            }
            onEditTargetedFeedbackChoices={(
              responseId: ActivityTypes.ResponseId,
              choiceIds: ActivityTypes.ChoiceId[],
            ) => dispatch(Actions.editTargetedFeedbackChoices(responseId, choiceIds))}
          />
        )}
      </Feedback>

      <HintsAuthoring
        addOne={() => dispatch(Actions.addHint())}
        updateOne={(id, content) => dispatch(Actions.editHint(id, content))}
        removeOne={(id) => dispatch(Actions.removeHint(id))}
        deerInHeadlightsHint={getHints(props.model)[0]}
        cognitiveHints={getHints(props.model).slice(1, getHints(props.model).length - 1)}
        bottomOutHint={getHints(props.model)[getHints(props.model).length - 1]}
      />
    </React.Fragment>
  );
};

export class CheckAllThatApplyAuthoring extends AuthoringElement<CheckAllThatApplyModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<CheckAllThatApplyModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <CheckAllThatApply {...props} />
        </AuthoringElementProvider>
        <ModalDisplay />
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, CheckAllThatApplyAuthoring);
