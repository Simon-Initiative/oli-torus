import React from 'react';
import ReactDOM from 'react-dom';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { CheckAllThatApplyModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Stem } from '../common/Stem';
import { Choices } from './sections/Choices';
import { Feedback } from './sections/Feedback';
import { Hints } from '../common/Hints';
import { Actions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import produce from 'immer';
import { TargetedFeedback } from 'components/activities/check_all_that_apply/sections/TargetedFeedback';
import { getHints, isTargetedCATA } from 'components/activities/check_all_that_apply/utils';

const store = configureStore();

const CheckAllThatApply = (props: AuthoringElementProps<CheckAllThatApplyModelSchema>) => {

  const dispatch = (action: any) =>
    props.onEdit(produce(props.model, draftState => action(draftState)));

  const sharedProps = {
    model: props.model,
    editMode: props.editMode,
    projectSlug: props.projectSlug,
  };

  return (
    <React.Fragment>
      <Stem {...sharedProps}
        stem={props.model.stem}
        onEditStem={content => dispatch(Actions.editStem(content))}
      />

      <Choices {...sharedProps}
        onAddChoice={() => dispatch(Actions.addChoice())}
        onEditChoiceContent={(id, content) => dispatch(Actions.editChoiceContent(id, content))}
        onRemoveChoice={id => dispatch(Actions.removeChoice(id))}
        onToggleChoiceCorrectness={choiceId => dispatch(Actions.toggleChoiceCorrectness(choiceId))}
      />

      <Feedback {...sharedProps}
        onEditResponseFeedback={(responseId, feedbackContent) =>
          dispatch(Actions.editResponseFeedback(responseId, feedbackContent))}
      >
        {isTargetedCATA(props.model)
          ? <TargetedFeedback {...sharedProps}
              model={props.model}
              onEditResponseFeedback={(responseId, feedbackContent) =>
                dispatch(Actions.editResponseFeedback(responseId, feedbackContent))}
              onAddTargetedFeedback={() => dispatch(Actions.addTargetedFeedback())}
              onRemoveTargetedFeedback={(responseId: ActivityTypes.ResponseId) =>
                dispatch(Actions.removeTargetedFeedback(responseId))}
              onEditTargetedFeedbackChoices={(choiceIds: ActivityTypes.ChoiceId[]) =>
                dispatch(Actions.editTargetedFeedbackChoices(choiceIds))}
          />
          : null}
      </Feedback>

      <div className="form-check mb-5">
        <input
          className="form-check-input"
          type="checkbox"
          value=""
          id="targeted-feedback-toggle"
          aria-label="Checkbox for targeted feedback"
          checked={props.model.type === 'TargetedCATA'}
          onChange={() => dispatch(Actions.toggleType())}
        />
        <label className="form-check-label" htmlFor="targeted-feedback-toggle">
          Targeted Feedback Mode
        </label>
      </div>

      <Hints
        projectSlug={props.projectSlug}
        hints={getHints(props.model)}
        editMode={props.editMode}
        onAddHint={() => dispatch(Actions.addHint())}
        onEditHint={(id, content) => dispatch(Actions.editHint(id, content))}
        onRemoveHint={id => dispatch(Actions.removeHint(id))} />
    </React.Fragment>
  );
};

export class CheckAllThatApplyAuthoring extends AuthoringElement<CheckAllThatApplyModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<CheckAllThatApplyModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <CheckAllThatApply {...props} />
        <ModalDisplay />
      </Provider>,
      mountPoint,
    );
  }
}

const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, CheckAllThatApplyAuthoring);
