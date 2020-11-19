import React, { useState } from 'react';
import ReactDOM from 'react-dom';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { CheckAllThatApplyModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Stem } from '../common/Stem';
import { Choices } from './sections/Choices';
import { Feedback } from './sections/Feedback';
import { Hints } from '../common/Hints';
import { Actions as CATAActions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import produce from 'immer';
import { TargetedFeedback } from 'components/activities/check_all_that_apply/sections/TargetedFeedback';
import { getResponses } from 'components/activities/check_all_that_apply/utils';

const store = configureStore();

const CheckAllThatApply = (props: AuthoringElementProps<CheckAllThatApplyModelSchema>) => {

  // Simple Mode: correct response + incorrect response
  // Targeted Feedback Mode: At least one other response
  const checkTargetedFeedback = (model: CheckAllThatApplyModelSchema) =>
    getResponses(model).length > 2;

  const dispatch = (action: any) => {
    const newModel = produce(props.model, draftState => action(draftState));
    setTargetedFeedbackMode(checkTargetedFeedback(newModel));
    props.onEdit(newModel);
  };

  const { projectSlug } = props;

  const [isInTargetedFeedbackMode, setTargetedFeedbackMode] =
    useState(checkTargetedFeedback(props.model));

  const sharedProps = {
    model: props.model,
    editMode: props.editMode,
    projectSlug,
  };

  return (
    <React.Fragment>
      <Stem
        projectSlug={props.projectSlug}
        editMode={props.editMode}
        stem={props.model.stem}
        onEditStem={content => dispatch(CATAActions.editStem(content))} />
      <Choices {...sharedProps}
        onAddChoice={() => dispatch(CATAActions.addChoice())}
        onEditChoiceContent={(id, content) => dispatch(CATAActions.editChoiceContent(id, content))}
        onRemoveChoice={id => dispatch(CATAActions.removeChoice(id))}
        onToggleChoiceCorrectness={choice =>
          dispatch(CATAActions.toggleChoiceCorrectness(choice))}
        />

      <div className="input-group mb-3">
        <div className="input-group-prepend">
          <div className="input-group-text">
            <input
              name="targeted-feedback-toggle"
              type="checkbox"
              aria-label="Checkbox for targeted feedback mode"
              checked={isInTargetedFeedbackMode}
              onClick={() => setTargetedFeedbackMode(!isInTargetedFeedbackMode)} />
          </div>
        </div>
        {/* Disable if > 5 answer choices */}
        <label htmlFor="targeted-feedback-toggle">Targeted Feedback Mode</label>
      </div>
        {isInTargetedFeedbackMode
        ? <TargetedFeedback {...sharedProps}
            // onEditResponseFeedback={(responseId, feedbackContent) =>
            //   dispatch(CATAActions.editResponseFeedback(responseId, feedbackContent))}
          />
        : <Feedback {...sharedProps}
            onEditCorrectFeedback={feedbackContent =>
              dispatch(CATAActions.editCorrectFeedback(feedbackContent))}
            onEditIncorrectFeedback={feedbackContent =>
              dispatch(CATAActions.editIncorrectFeedback(feedbackContent))}
          />}

      <Hints
        projectSlug={props.projectSlug}
        hints={props.model.authoring.parts[0].hints}
        editMode={props.editMode}
        onAddHint={() => dispatch(CATAActions.addHint())}
        onEditHint={(id, content) => dispatch(CATAActions.editHint(id, content))}
        onRemoveHint={id => dispatch(CATAActions.removeHint(id))} />
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
