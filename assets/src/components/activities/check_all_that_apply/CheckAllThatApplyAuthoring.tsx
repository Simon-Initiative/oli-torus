import React from 'react';
import ReactDOM from 'react-dom';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { CheckAllThatApplyModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Stem } from '../common/Stem';
import { Choices } from './sections/Choices';
import { Feedback } from './sections/Feedback';
import { Hints } from '../common/Hints';
import { CATAActions } from './actions';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import produce from 'immer';

const store = configureStore();

const CheckAllThatApply = (props: AuthoringElementProps<CheckAllThatApplyModelSchema>) => {

  const dispatch = (action: any) => {
    props.onEdit(produce(props.model, draftState => action(draftState)));
  };

  const { projectSlug } = props;

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
        onEditChoice={(id, content) => dispatch(CATAActions.editChoice(id, content))}
        onRemoveChoice={id => dispatch(CATAActions.removeChoice(id))} />
      <Feedback {...sharedProps}
        onEditResponse={(id, content) => dispatch(CATAActions.editFeedback(id, content))} />
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
        <ModalDisplay/>
      </Provider>,
      mountPoint,
    );
  }
}

const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, CheckAllThatApplyAuthoring);
